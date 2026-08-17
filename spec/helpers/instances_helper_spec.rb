# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InstancesHelper, type: :helper do
  RDF_VALUE   = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#value'
  LITERALFORM = 'http://www.w3.org/2008/05/skos-xl#literalForm'
  SKOS_NOTE   = 'http://www.w3.org/2004/02/skos/core#note'
  SOURCE      = 'http://purl.org/dc/terms/source'
  RDFS_LABEL  = 'http://www.w3.org/2000/01/rdf-schema#label'

  def instance(properties)
    { properties: properties }
  end

  describe '#resource_value' do
    it 'picks the text a reified definition node carries under rdf:value' do
      node = instance(RDF_VALUE => ['A parasitic disease.'],
                      SOURCE => ['Adapté de : Baize, D. (2016)'])

      expect(helper.resource_value(node)).to eq([RDF_VALUE, ['A parasitic disease.']])
    end

    it 'leaves every other predicate alone, for Raw data to list' do
      node = instance(RDF_VALUE => ['A parasitic disease.'], SOURCE => ['Baize, D.'])

      _predicate, values = helper.resource_value(node)
      expect(values).not_to include('Baize, D.')
    end

    it 'prefers the more specific predicate when a node carries several' do
      node = instance(SKOS_NOTE => ['a note'], RDF_VALUE => ['the value'])

      expect(helper.resource_value(node).first).to eq(RDF_VALUE)
    end

    it 'falls back to the SKOS-XL literal form' do
      node = instance(LITERALFORM => ['Etiology'])

      expect(helper.resource_value(node)).to eq([LITERALFORM, ['Etiology']])
    end

    it 'keeps every value when the text is tagged in several languages' do
      node = instance(RDF_VALUE => ['Une maladie parasitaire.', 'A parasitic disease.'])

      expect(helper.resource_value(node).last.size).to eq(2)
    end

    it 'is nil for an ordinary individual, whose text is its label' do
      node = instance(RDFS_LABEL => ['wind action'], SOURCE => ['somewhere'])

      expect(helper.resource_value(node)).to be_nil
    end

    it 'is nil when the predicate is there but holds nothing' do
      expect(helper.resource_value(instance(RDF_VALUE => []))).to be_nil
      expect(helper.resource_value(instance(RDF_VALUE => ['']))).to be_nil
    end

    it 'reads predicates however the API client keyed them' do
      node = instance(RDF_VALUE.to_sym => ['A parasitic disease.'])

      expect(helper.resource_value(node)).to eq([RDF_VALUE, ['A parasitic disease.']])
    end
  end
end
