require 'spec_helper'
require 'ostruct'
require 'json'
require 'action_view'
require 'active_support/all'
require_relative '../../app/helpers/metadata_tags_helper'

RSpec.describe MetadataTagsHelper do
  # A minimal view-like context: the real ActionView tag / sanitize / output-safety
  # helpers the module relies on, plus the two collaborators it expects from the
  # application (link? from UrlsHelper, and request).
  let(:helper) do
    Class.new do
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::SanitizeHelper
      include ActionView::Helpers::OutputSafetyHelper
      include MetadataTagsHelper

      def link?(str)
        str.to_s.start_with?('http://', 'https://')
      end

      def request
        nil
      end

      # Stand-in for ActionView's TranslationHelper, with site interpolation.
      def t(key, **opts)
        case key.to_s
        when 'home.catalog.description' then "#{opts[:site]} is a repository."
        when 'home.catalog.keywords' then ['agriculture', 'ontology', 'semantic web']
        else opts[:default]
        end
      end
    end.new
  end

  let(:ontology) { OpenStruct.new(acronym: 'AGRO', name: 'Agronomy Ontology') }

  before do
    $UI_URL = 'https://agroportal.example.org'
    $ORG_SITE = 'AgroPortal'
  end

  def extract_json(html)
    JSON.parse(html.to_s[%r{<script[^>]*>(.+)</script>}m, 1])
  end

  describe '#ontology_head_metadata' do
    it 'returns nil when there is no ontology' do
      expect(helper.ontology_head_metadata(nil, nil)).to be_nil
    end

    it 'returns nil when the ontology has no acronym' do
      expect(helper.ontology_head_metadata(OpenStruct.new(acronym: nil), nil)).to be_nil
    end

    it 'renders both meta tags and JSON-LD for a valid ontology' do
      html = helper.ontology_head_metadata(ontology, nil).to_s
      expect(html).to include('rel="canonical"')
      expect(html).to include('application/ld+json')
    end
  end

  describe '#ontology_json_ld' do
    it 'renders a schema.org Dataset flagged as Bioschemas-conformant' do
      json = extract_json(helper.ontology_json_ld(ontology, nil))
      expect(json['@type']).to eq('Dataset')
      expect(json['@context']).to include('@vocab' => 'https://schema.org/')
      expect(json['name']).to eq('Agronomy Ontology')
      expect(json['identifier']).to eq('AGRO')
      expect(json['url']).to eq('https://agroportal.example.org/ontologies/AGRO')
      expect(json.dig('dct:conformsTo', '@id')).to eq(MetadataTagsHelper::BIOSCHEMAS_DATASET_PROFILE)
      expect(json['includedInDataCatalog']).to eq('@type' => 'DataCatalog', 'name' => 'AgroPortal',
                                                  'url' => 'https://agroportal.example.org')
    end

    it 'maps submission metadata into the dataset and strips HTML from text' do
      submission = OpenStruct.new(
        description: '<p>An <b>agronomy</b> ontology.</p>',
        version: '2.3',
        hasLicense: 'https://creativecommons.org/licenses/by/4.0/',
        naturalLanguage: %w[en fr],
        keywords: ['crops, soil'],
        hasDomain: ['agriculture'],
        released: '2024-01-01',
        dataDump: 'https://agroportal.example.org/data/AGRO.ttl',
        hasCreator: [OpenStruct.new(agentType: 'organization', name: 'INRAE')]
      )

      json = extract_json(helper.ontology_json_ld(ontology, submission))
      expect(json['description']).to eq('An agronomy ontology.')
      expect(json['version']).to eq('2.3')
      expect(json['license']).to eq('https://creativecommons.org/licenses/by/4.0/')
      expect(json['inLanguage']).to eq(%w[en fr])
      expect(json['keywords']).to contain_exactly('crops', 'soil', 'agriculture')
      expect(json['creator']).to eq([{ '@type' => 'Organization', 'name' => 'INRAE' }])
      expect(json['datePublished']).to eq('2024-01-01')
      expect(json.dig('distribution', 0, 'contentUrl')).to eq('https://agroportal.example.org/data/AGRO.ttl')
    end

    it 'maps the extended AgroPortal metadata into schema.org keys' do
      submission = OpenStruct.new(
        homepage: 'https://agro.example.org',
        alternative: ['Agro Ontology', 'AGRO'],
        useGuidelines: 'https://agro.example.org/guidelines',
        award: ['Best Ontology 2024'],
        coverage: ['Europe'],
        audience: ['Researchers'],
        curatedBy: [OpenStruct.new(name: 'Jane Curator')],
        translator: [OpenStruct.new(name: 'Tom Translator')],
        fundedBy: [OpenStruct.new(agentType: 'organization', name: 'EU')],
        copyrightHolder: 'https://ror.org/00x0z1234'
      )

      json = extract_json(helper.ontology_json_ld(ontology, submission))
      expect(json['sameAs']).to eq(['https://agro.example.org'])
      expect(json['alternateName']).to contain_exactly('AGRO', 'Agro Ontology')
      expect(json['usageInfo']).to eq('https://agro.example.org/guidelines')
      expect(json['award']).to eq(['Best Ontology 2024'])
      expect(json['audience']).to eq([{ '@type' => 'Audience', 'audienceType' => 'Researchers' }])
      expect(json['spatialCoverage']).to eq([{ '@type' => 'Place', 'name' => 'Europe' }])
      expect(json['editor']).to eq([{ '@type' => 'Person', 'name' => 'Jane Curator' }])
      expect(json['translator']).to eq([{ '@type' => 'Person', 'name' => 'Tom Translator' }])
      expect(json['funder']).to eq([{ '@type' => 'Organization', 'name' => 'EU' }])
      expect(json['copyrightHolder']).to eq([{ '@id' => 'https://ror.org/00x0z1234' }])
    end

    it 'falls back to the acronym for the name and omits blank fields' do
      json = extract_json(helper.ontology_json_ld(OpenStruct.new(acronym: 'XYZ'), nil))
      expect(json['name']).to eq('XYZ')
      expect(json).not_to have_key('description')
      expect(json).not_to have_key('keywords')
    end

    it 'escapes characters that could break out of the <script> tag' do
      submission = OpenStruct.new(description: 'x</script><img src=q onerror=alert(1)>')
      html = helper.ontology_json_ld(ontology, submission).to_s
      expect(html).not_to include('</script><img')
      expect(html).to include('</script')
    end
  end

  describe '#home_catalog_json_ld' do
    before do
      $SITE = 'AgroPortal'
      $ORG = 'INRAE'
      $ORG_URL = 'https://www.inrae.fr'
    end

    it 'renders a schema.org DataCatalog describing the portal' do
      json = extract_json(helper.home_catalog_json_ld)
      expect(json['@type']).to eq('DataCatalog')
      expect(json['name']).to eq('AgroPortal')
      expect(json['url']).to eq('https://agroportal.example.org')
      expect(json['description']).to eq('AgroPortal is a repository.')
      expect(json['keywords']).to eq(%w[agriculture ontology] + ['semantic web'])
      expect(json['isAccessibleForFree']).to be(true)
      expect(json['publisher']).to eq('@type' => 'Organization', 'name' => 'INRAE',
                                      'url' => 'https://www.inrae.fr')
    end

    it 'returns nil when the portal has no name or no UI URL' do
      $SITE = nil
      $ORG_SITE = nil
      expect(helper.home_catalog_json_ld).to be_nil
    end
  end

  describe '#ontology_meta_tags' do
    it 'emits canonical, description, Open Graph and Twitter tags' do
      submission = OpenStruct.new(description: 'Hello world', logo: 'https://x/logo.png')
      html = helper.ontology_meta_tags(ontology, submission).to_s

      expect(html).to include('<link rel="canonical" href="https://agroportal.example.org/ontologies/AGRO"')
      expect(html).to include('name="description" content="Hello world"')
      expect(html).to include('property="og:title" content="Agronomy Ontology"')
      expect(html).to include('property="og:image" content="https://x/logo.png"')
      expect(html).to include('name="twitter:card" content="summary_large_image"')
    end

    it 'uses a plain summary card when there is no logo' do
      html = helper.ontology_meta_tags(ontology, nil).to_s
      expect(html).to include('name="twitter:card" content="summary"')
      expect(html).not_to include('og:image')
    end
  end
end
