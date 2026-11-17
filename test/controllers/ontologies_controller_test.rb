# frozen_string_literal: true

require 'test_helper'

class OntologiesControllerTest < ActionDispatch::IntegrationTest
  ONTOLOGIES = LinkedData::Client::Models::Ontology.all(include: 'acronym')
  PAGES = %w[summary classes properties notes mappings schemes collections widgets].freeze

  test 'should return all the ontologies' do
    get ontologies_path
    assert_response :success
  end

  # We use only the STY ontology to test to avoid long tests
  SAMPLE_ACRONYMS = %w[STY].freeze
  SAMPLE_ACRONYMS.each do |ont_acronym|
    PAGES.each do |page|
      test "should get page #{page} of #{ont_acronym} ontology" do
        path = "#{ontologies_path}/#{ont_acronym}?p=#{page}"
        get path
        if response.redirect?
          follow_redirect!
        end
        assert_response :success, "GET #{path} returned #{response.status}"
      end
    end

    test "should open the tree views of #{ont_acronym} ontology" do
      paths = [
        ajax_classes_treeview_path(ontology: ont_acronym),
        "/ontologies/#{ont_acronym}/properties"
      ]
      paths.each do |path|
        begin
          get path
          assert_includes [404, 200], response.status,  "GET #{path} returned #{response.status}"
        rescue StandardError => e
          assert_equal ActiveRecord::RecordNotFound, e.class
        end
      end

    end
  end

  test 'test get STY in html format' do
    get '/ontologies/STY', headers: { 'Accept' => 'text/html' }
    assert_response :success
    assert_equal 'text/html; charset=utf-8', response.content_type
  end

  test 'test get STY in json format' do
    get '/ontologies/STY', headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal 'application/json', response.content_type

  end

  test 'test get STY in xml format' do
    get '/ontologies/STY', headers: { 'Accept' => 'application/xml' }
    if $REST_URL == "https://data.stageportal.lirmm.fr/"
      assert_response :success
    else
      assert_equal 500, response.status # STY does not have xml in localhost:9393
    end
  end

  test 'test get STY in csv format' do
    get '/ontologies/STY', headers: { 'Accept' => 'text/csv' }
    assert_response :success
  end

  test 'test get STY in turtle format' do
    get '/ontologies/STY', headers: { 'Accept' => 'text/turtle' }
    assert_response :success
  end

  test 'test get STY in ntriples format' do
    get '/ontologies/STY', headers: { 'Accept' => 'application/ntriples' }
    assert_response :not_acceptable
  end

  
  test 'test get STY resource in html format' do
    get '/ontologies/STY/T071', headers: { 'Accept' => 'text/html' }
    assert_includes ["http://www.example.com/ontologies/STY?conceptid=http%3A%2F%2Fpurl.bioontology.org%2Fontology%2FSTY%2FT071&p=classes", "http://www.example.com/ontologies/STY?conceptid=http%3A%2F%2Fpurl.lirmm.fr%2Fontology%2FSTY%2FT071&p=classes"], response.location
    assert_response :redirect
    assert_equal "text/html; charset=utf-8" , response.content_type
  end
  
  test 'test get STY resource in json format' do
    get '/ontologies/STY/T071', headers: { 'Accept' => 'application/json' }
    assert_response :success
    assert_equal "application/ld+json; charset=utf-8" , response.content_type
  end

  test 'test get STY resource in xml format' do
    get '/ontologies/STY/T071', headers: { 'Accept' => 'application/xml' }
    assert_response :success
    assert_equal "application/rdf+xml; charset=utf-8" , response.content_type
  end

  test 'test get STY resource in ntriples format' do
    get '/ontologies/STY/T071', headers: { 'Accept' => 'application/n-triples' }
    assert_response :success
    assert_equal "application/n-triples; charset=utf-8" , response.content_type
  end

  test 'test get STY resource in turtle format' do
    get '/ontologies/STY/T071', headers: { 'Accept' => 'text/turtle' }
    assert_response :success
    assert_equal "text/turtle; charset=utf-8" , response.content_type
  end

  test 'should render an untyped node the API cannot serve' do
    node = 'http://aims.fao.org/aos/agrovoc/xDef_d8a81e42'
    definition = 'A temporary endeavour with a defined beginning and end.'
    rdf_value = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#value'

    # The API answers 500 for a node with no owl:NamedIndividual type, like
    # AGROVOC's reified definitions; only SPARQL knows what it holds
    stub_request(:get, /instances.*xDef_d8a81e42/).to_return(status: 500, body: '<h1>Internal Server Error</h1>')
    stub_request(:get, /sparql\.example\.org/).to_return(
      headers: { 'Content-Type' => 'application/sparql-results+json' },
      body: { results: { bindings: [{ p: { type: 'uri', value: rdf_value },
                                       o: { type: 'literal', value: definition, 'xml:lang': 'en' } }] } }.to_json
    )
    previous_endpoint = $SPARQL_ENDPOINT_URL
    $SPARQL_ENDPOINT_URL = 'https://sparql.example.org/sparql'
    Rails.cache.clear

    get "/ontologies/STY?p=instances&instanceid=#{CGI.escape(node)}"

    assert_response :success
    assert_includes response.body, definition
  ensure
    $SPARQL_ENDPOINT_URL = previous_endpoint
  end
end
