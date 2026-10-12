# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class EntityGraphServiceTest < ActiveSupport::TestCase
  ACRONYM = 'TST'
  CLASSES = "http://api.test/ontologies/#{ACRONYM}/classes"
  TOP = 'http://purl.obolibrary.org/obo/TST_0000001'
  MID = 'http://purl.obolibrary.org/obo/TST_0000002'
  LEAF = 'http://purl.obolibrary.org/obo/TST_0000003'
  FILLER = 'http://purl.obolibrary.org/obo/TST_0000004'
  PART_OF = 'http://purl.obolibrary.org/obo/BFO_0000050'
  ONLY_IN_TAXON = 'http://purl.obolibrary.org/obo/RO_0002160'
  VIRIDIPLANTAE = 'http://purl.obolibrary.org/obo/NCBITaxon_33090'

  # AgroPortal answers 500 to paths_to_root on every SKOS ontology, and the API
  # client raises a bare Exception, not a StandardError, for a 5xx
  test 'walks the parents when paths_to_root answers 5xx' do
    parents = { LEAF => [cls(MID, 'cereals')], MID => [cls(TOP, 'products')], TOP => [] }
    server_error = ->(*, **) { raise Exception, 'Problem retrieving: 500 Internal Server Error' }

    graph = LinkedData::Client::HTTP.stub(:get, server_error) do
      LinkedData::Client::Models::Ontology.stub(:explore, parents_explorer(parents)) do
        build_graph(ontology('SKOS'), cls(LEAF, 'wheat'))
      end
    end

    assert_equal [[LEAF, MID], [MID, TOP]], edges(graph, 'is-a')
    assert node(graph, TOP)[:hierarchyRoot]
  end

  # `part of` arrives in the portal namespace as …/metadata/obo/part_of
  test 'draws OBO shorthand relations of the portal metadata namespace' do
    leaf = cls(LEAF, 'mitochondrion', properties: { 'https://data.agroportal.eu/metadata/obo/part_of' => [FILLER] })
    classes = [cls(TOP, 'cellular component'), leaf, cls(FILLER, 'cytoplasm')].index_by(&:id)
    paths = { LEAF => [[classes[TOP], leaf]], FILLER => [[classes[TOP], classes[FILLER]]] }
    paths_to_root = ->(url, *, **) { paths.find { |id, _| url.include?(CGI.escape(id)) }&.last }

    graph = LinkedData::Client::HTTP.stub(:get, paths_to_root) do
      build_graph(ontology('OWL', classes: classes), leaf)
    end

    assert_equal [[LEAF, FILLER]], edges(graph, 'rel')
    assert_equal ['part of', PART_OF], graph[:edges].find { |e| e[:kind] == 'rel' }.values_at(:label, :prop_id)
    assert_equal [[LEAF, TOP], [FILLER, TOP]], edges(graph, 'is-a')
    assert_equal 'cytoplasm', node(graph, FILLER)[:label]
  end

  # PO states "only in taxon Viridiplantae" high in its hierarchy
  test 'leaves the taxon lineage out' do
    leaf = cls(LEAF, 'leaf', properties: { ONLY_IN_TAXON => [VIRIDIPLANTAE] })
    classes = [cls(TOP, 'plant anatomical entity'), leaf, cls(VIRIDIPLANTAE, 'Viridiplantae')].index_by(&:id)

    graph = LinkedData::Client::HTTP.stub(:get, ->(*, **) { [[classes[TOP], leaf]] }) do
      build_graph(ontology('OWL', classes: classes), leaf)
    end

    assert_empty edges(graph, 'rel')
    assert_nil node(graph, VIRIDIPLANTAE)
  end

  private

  def build_graph(ontology, concept)
    EntityGraphService.call(ontology, concept, helpers: ApplicationController.helpers, lang: 'EN')
  end

  def edges(graph, kind)
    graph[:edges].select { |e| e[:kind] == kind }.map { |e| [e[:from], e[:to]] }
  end

  def node(graph, id)
    graph[:nodes].find { |n| n[:id] == id }
  end

  def cls(id, label, properties: {})
    OpenStruct.new(id: id, prefLabel: label, definition: [], synonym: [], properties: properties)
  end

  # An ontology whose object properties are `part of` and `only in taxon`
  def ontology(language, classes: {})
    properties = { PART_OF => 'part of', ONLY_IN_TAXON => 'only in taxon' }.map do |id, label|
      OpenStruct.new(id: id, type: 'http://www.w3.org/2002/07/owl#ObjectProperty', label: [label], children: [])
    end
    explore = api_stub(latest_submission: OpenStruct.new(hasOntologyLanguage: language))
    explore.define_singleton_method(:single_class) { |_params, id| classes[id] }

    OpenStruct.new(acronym: ACRONYM, links: { 'classes' => CLASSES }, explore: explore,
                   property_tree: OpenStruct.new(children: properties))
  end

  # Ontology.explore(acronym).classes(id).parents.get(...) => parents[id]
  def parents_explorer(parents)
    explorer = Object.new
    explorer.define_singleton_method(:classes) do |id|
      api_parents = Object.new
      api_parents.define_singleton_method(:parents) { Object.new.tap { |p| p.define_singleton_method(:get) { |*| parents[id] } } }
      api_parents
    end
    ->(*) { explorer }
  end

  # Answers every call to each method with the same value, whatever the arguments
  def api_stub(**answers)
    Object.new.tap do |stub|
      answers.each { |name, answer| stub.define_singleton_method(name) { |*| answer } }
    end
  end
end
