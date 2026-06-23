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

      # Stand-in for the controller's portal_catalog_config helper_method.
      def portal_catalog_config
        {}
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
      expect(json['includedInDataCatalog']).to eq('@type' => 'DataCatalog',
                                                  '@id' => 'https://agroportal.example.org',
                                                  'name' => 'AgroPortal',
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
      # omv:keywords -> schema:keywords; omv:hasDomain -> schema:about (subject)
      expect(json['keywords']).to contain_exactly('crops', 'soil')
      expect(json['about']).to eq(['agriculture'])
      expect(json['creator']).to eq([{ '@type' => 'Organization', 'name' => 'INRAE' }])
      expect(json['author']).to eq([{ '@type' => 'Organization', 'name' => 'INRAE' }])
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
      # foaf:homepage -> schema:mainEntityOfPage
      expect(json['mainEntityOfPage']).to eq(['https://agro.example.org'])
      expect(json['alternateName']).to contain_exactly('AGRO', 'Agro Ontology')
      expect(json['usageInfo']).to eq('https://agro.example.org/guidelines')
      expect(json['award']).to eq(['Best Ontology 2024'])
      expect(json['audience']).to eq([{ '@type' => 'Audience', 'audienceType' => 'Researchers' }])
      expect(json['spatialCoverage']).to eq([{ '@type' => 'Place', 'name' => 'Europe' }])
      # pav:curatedBy -> schema:maintainer
      expect(json['maintainer']).to eq([{ '@type' => 'Person', 'name' => 'Jane Curator' }])
      expect(json['translator']).to eq([{ '@type' => 'Person', 'name' => 'Tom Translator' }])
      expect(json['funder']).to eq([{ '@type' => 'Organization', 'name' => 'EU' }])
      expect(json['copyrightHolder']).to eq([{ '@id' => 'https://ror.org/00x0z1234' }])
    end

    it 'maps the remaining MOD metadata into schema.org keys' do
      submission = OpenStruct.new(
        abstract: 'A short abstract.',
        notes: ['Internal note'],
        isOfType: ['Vocabulary'],
        status: 'production',
        viewingRestriction: 'public',
        metadataVoc: ['https://w3id.org/mod'],
        logo: 'https://agro.example.org/logo.png',
        depiction: 'https://agro.example.org/depiction.png',
        associatedMedia: ['https://agro.example.org/media.mp4'],
        contact: [{ name: 'Jane Doe', email: 'JANE@example.org' }],
        documentation: 'https://agro.example.org/docs',
        publication: ['Doe J. 2024'],
        repository: 'https://github.com/agro/agro',
        usedOntologyEngineeringTool: ['Protégé'],
        accrualPeriodicity: 'annual',
        source: ['https://agro.example.org/source'],
        viewOf: ['PARENT'],
        hasPart: ['PART'],
        ontologyRelatedTo: ['RELATED'],
        example: ['https://agro.example.org/example'],
        diffFilePath: 'https://agro.example.org/diff',
        toDoList: ['Add definitions'],
        creationDate: '2023-05-05',
        modificationDate: '2024-06-06'
      )

      json = extract_json(helper.ontology_json_ld(ontology, submission))
      expect(json['abstract']).to eq('A short abstract.')
      expect(json['comment']).to eq(['Internal note'])
      expect(json['additionalType']).to eq(['Vocabulary'])
      expect(json['creativeWorkStatus']).to eq('production')
      expect(json['conditionsOfAccess']).to eq('public')
      expect(json['schemaVersion']).to eq(['https://w3id.org/mod'])
      expect(json['logo']).to eq('https://agro.example.org/logo.png')
      expect(json['image']).to eq(['https://agro.example.org/depiction.png'])
      expect(json['associatedMedia']).to eq([{ '@type' => 'MediaObject',
                                               'contentUrl' => 'https://agro.example.org/media.mp4' }])
      expect(json['contactPoint']).to eq([{ '@type' => 'ContactPoint', 'name' => 'Jane Doe',
                                            'email' => 'jane@example.org' }])
      expect(json['documentation']).to eq('https://agro.example.org/docs')
      expect(json['citation']).to eq(['Doe J. 2024'])
      expect(json['codeRepository']).to eq('https://github.com/agro/agro')
      expect(json['instrument']).to eq([{ '@type' => 'Thing', 'name' => 'Protégé' }])
      # dcterms:accrualPeriodicity -> schema:repeatFrequency is off-domain on a
      # Dataset (warns), so it is intentionally not emitted.
      expect(json).not_to have_key('repeatFrequency')
      expect(json['isBasedOn']).to eq(['https://agro.example.org/source'])
      expect(json['isPartOf']).to eq(['PARENT'])
      expect(json['hasPart']).to eq(['PART'])
      expect(json['isRelatedTo']).to eq(['RELATED'])
      expect(json['workExample']).to eq(['https://agro.example.org/example'])
      expect(json['releaseNotes']).to eq('https://agro.example.org/diff')
      expect(json['potentialAction']).to eq([{ '@type' => 'Action', 'name' => 'Add definitions' }])
      expect(json['dateCreated']).to eq('2023-05-05')
      expect(json['dateModified']).to eq('2024-06-06')
    end

    it 'falls back to dcterms:created for dateCreated when creationDate is absent' do
      submission = OpenStruct.new(created: '2020-01-01')
      json = extract_json(helper.ontology_json_ld(ontology, submission))
      expect(json['dateCreated']).to eq('2020-01-01')
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
      # description and keywords come only from the live catalog, not the locale files
      expect(json).not_to have_key('description')
      expect(json).not_to have_key('keywords')
      expect(json['publisher']).to eq('@type' => 'Organization', 'name' => 'INRAE',
                                      'url' => 'https://www.inrae.fr')
    end

    it 'returns nil when the portal has no name or no UI URL' do
      $SITE = nil
      $ORG_SITE = nil
      expect(helper.home_catalog_json_ld).to be_nil
    end

    it 'prefers the live portal catalog config over the globals' do
      allow(helper).to receive(:portal_catalog_config).and_return(
        identifier: 'AGROPORTAL',
        title: 'AgroPortal Catalog',
        ui: 'https://catalog.example.org',
        landingPage: 'https://catalog.example.org/about',
        accessURL: 'https://catalog.example.org/sparql',
        description: 'The reference repository for agronomy ontologies.',
        subject: ['Agriculture'],
        keyword: ['agronomy, crops'],
        language: %w[en fr],
        license: 'https://creativecommons.org/licenses/by/4.0/',
        bibliographicCitation: ['Toulet et al. 2024'],
        coverage: ['Europe'],
        accrualPeriodicity: 'monthly',
        created: '2015-06-01',
        creator: [OpenStruct.new(agentType: 'organization', name: 'INRAE')],
        contributor: [OpenStruct.new(name: 'Jane Doe')],
        fundedBy: [{ url: 'https://anr.fr', img_src: 'anr.png' }],
        contactPoint: [{ name: 'Support Team', email: 'SUPPORT@example.org',
                         agentType: 'person', '@id' => 'https://data.example.org/Agents/x' }]
      )

      json = extract_json(helper.home_catalog_json_ld)
      expect(json['identifier']).to eq('AGROPORTAL')
      expect(json['name']).to eq('AgroPortal Catalog')
      expect(json['url']).to eq('https://catalog.example.org')
      expect(json['documentation']).to eq('https://catalog.example.org/about')
      expect(json['description']).to eq('The reference repository for agronomy ontologies.')
      expect(json['about']).to eq(['Agriculture'])
      expect(json['keywords']).to contain_exactly('agronomy', 'crops')
      expect(json['inLanguage']).to eq(%w[en fr])
      expect(json['license']).to eq('https://creativecommons.org/licenses/by/4.0/')
      expect(json['citation']).to eq(['Toulet et al. 2024'])
      expect(json['spatialCoverage']).to eq([{ '@type' => 'Place', 'name' => 'Europe' }])
      expect(json['dateCreated']).to eq('2015-06-01')
      # accessURL -> contentUrl and accrualPeriodicity -> repeatFrequency are
      # off-domain on a DataCatalog (warn), so they are not emitted.
      expect(json).not_to have_key('contentUrl')
      expect(json).not_to have_key('repeatFrequency')
      expect(json['creator']).to eq([{ '@type' => 'Organization', 'name' => 'INRAE' }])
      expect(json['author']).to eq([{ '@type' => 'Organization', 'name' => 'INRAE' }])
      expect(json['contributor']).to eq([{ '@type' => 'Person', 'name' => 'Jane Doe' }])
      expect(json['funder']).to eq([{ '@type' => 'Organization', 'url' => 'https://anr.fr', 'logo' => 'anr.png' }])
      expect(json['contactPoint']).to eq([{ '@type' => 'ContactPoint', 'name' => 'Support Team',
                                            'email' => 'support@example.org' }])
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
