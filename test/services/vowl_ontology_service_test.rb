# frozen_string_literal: true

require 'test_helper'

class VowlOntologyServiceTest < ActiveSupport::TestCase
  WHEAT = 'http://x/wheat'
  CEREAL = 'http://x/cereal'
  WATER = 'http://x/water'

  def graph(edges)
    {
      nodes: [
        { id: WHEAT, label: 'blé', definition: 'Triticum', synonyms: %w[froment épeautre] },
        { id: CEREAL, label: 'cereal' },
        { id: WATER, label: 'water' }
      ],
      edges: edges
    }
  end

  def vowl(edges, language: 'fr')
    VowlOntologyService.call(graph(edges), iri: WHEAT, title: 'DEMO', language: language)
  end

  test 'publishes a class per node, keyed by the id its properties point at' do
    result = vowl([])

    assert_equal %w[0 1 2], result[:class].map { |klass| klass[:id] }
    assert_equal ['owl:Class'] * 3, result[:class].map { |klass| klass[:type] }
    assert_equal [WHEAT, CEREAL, WATER], result[:classAttribute].map { |klass| klass[:iri] }
  end

  test 'sends an is-a edge from the subclass to the superclass' do
    result = vowl([{ from: WHEAT, to: CEREAL, kind: 'is-a' }])

    assert_equal 'rdfs:SubClassOf', result[:property].first[:type]
    assert_equal({ id: '0', domain: '0', range: '1' }, result[:propertyAttribute].first)
  end

  test 'publishes an asserted relationship as a labelled object property' do
    result = vowl([{ from: WHEAT, to: WATER, kind: 'rel',
                     label: 'grows in', prop_id: 'http://x/growsIn' }])
    property = result[:propertyAttribute].first

    assert_equal 'owl:ObjectProperty', result[:property].first[:type]
    assert_equal 'http://x/growsIn', property[:iri]
    assert_equal 'grows in', property[:label]['fr']
    assert_equal ['object'], property[:attributes]
  end

  test 'drops an edge whose endpoint is not in the payload' do
    result = vowl([{ from: WHEAT, to: 'http://x/elsewhere', kind: 'is-a' },
                   { from: WHEAT, to: CEREAL, kind: 'is-a' }])

    assert_equal 1, result[:property].size
    assert_equal 1, result[:metrics][:propertyCount]
    assert_equal '1', result[:propertyAttribute].first[:range]
  end

  test 'labels every element in the request language and under the fallback' do
    result = vowl([], language: 'fr')
    label = result[:classAttribute].first[:label]

    assert_equal %w[fr undefined], result[:header][:languages]
    assert_equal 'blé', label['fr']
    assert_equal 'blé', label['undefined']
  end

  test 'carries synonyms as a single annotation, and none when there are none' do
    result = vowl([])

    synonym = result[:classAttribute].first[:annotations]['synonym'].first
    assert_equal 'froment, épeautre', synonym[:value]
    assert_not result[:classAttribute].second.key?(:annotations)
  end
end
