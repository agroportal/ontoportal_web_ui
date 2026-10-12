# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class ConceptsControllerTest < ActionDispatch::IntegrationTest
  ACRONYM = 'PO'
  CLASS_ID = 'http://purl.obolibrary.org/obo/PO_0025034'
  GRAPH = { root: CLASS_ID, nodes: [{ id: CLASS_ID, label: 'leaf', selected: true }], edges: [],
            edge_count: 0, truncated: false, large: false }.freeze

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test 'the graph endpoint answers 404 while ENTITY_GRAPH is off' do
    Flipper.disable(ConceptsHelper::ENTITY_GRAPH_FEATURE)

    get_graph

    assert_response :not_found
  end

  test 'the graph endpoint renders the graph frame while ENTITY_GRAPH is on' do
    get_graph

    assert_response :success
    assert_select 'turbo-frame#concept_entity_graph .entity-graph[data-controller=?]', 'concept-graph'
    assert_select '[data-concept-graph-class-url-value=?]', "/ontologies/#{ACRONYM}?p=classes&view=concept-graph&language=EN"
  end

  private

  def get_graph
    concept = OpenStruct.new(id: CLASS_ID, prefLabel: 'leaf')
    ontology = OpenStruct.new(acronym: ACRONYM, explore: api_stub(single_class: concept))

    LinkedData::Client::Models::Ontology.stub(:find_by_acronym, [ontology]) do
      EntityGraphService.stub(:call, GRAPH) do
        get '/ajax/entity_graph', params: { ontology: ACRONYM, conceptid: CLASS_ID, language: 'en' }
      end
    end
  end

  # Answers every call to each method with the same value, whatever the arguments
  def api_stub(**answers)
    Object.new.tap do |stub|
      answers.each { |name, answer| stub.define_singleton_method(name) { |*| answer } }
    end
  end
end
