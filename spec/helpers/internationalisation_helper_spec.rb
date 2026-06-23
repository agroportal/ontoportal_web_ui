require 'spec_helper'
require 'i18n'
require_relative '../../app/helpers/internationalisation_helper'

RSpec.describe InternationalisationHelper do
  describe '.t' do
    after { $RESOURCE_TERM = nil }

    it 'passes translations straight through when no resource term is configured' do
      $RESOURCE_TERM = nil
      allow(I18n).to receive(:t).with('home.catalog.keywords').and_return(%w[agriculture ontology])

      expect(described_class.t('home.catalog.keywords')).to eq(%w[agriculture ontology])
    end

    # Regression: with a resource term set, the override used to call
    # String#downcase on every translation, which blew up on array-valued
    # locale keys (e.g. home.catalog.keywords) and rendered the error text.
    it 'returns array-valued translations unchanged when a resource term is set' do
      $RESOURCE_TERM = 'semantic_artefact'
      allow(I18n).to receive(:t).and_return(%w[agriculture ontology semantic\ web])

      expect(described_class.t('home.catalog.keywords')).to eq(['agriculture', 'ontology', 'semantic web'])
    end
  end
end
