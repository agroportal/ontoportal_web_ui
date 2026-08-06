# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResourceLookupService do
  let(:node) { 'http://aims.fao.org/aos/agrovoc/xDef_46a719b8' }
  let(:value_predicate) { 'http://www.w3.org/1999/02/22-rdf-syntax-ns#value' }
  let(:source_predicate) { 'http://art.uniroma2.it/ontologies/vocbench#hasSource' }

  def sparql_response(bindings)
    instance_double(Faraday::Response, success?: true,
                                       body: { results: { bindings: bindings } }.to_json)
  end

  def binding_for(predicate, value)
    { 'p' => { 'type' => 'uri', 'value' => predicate }, 'o' => { 'type' => 'literal', 'value' => value } }
  end

  before do
    $SPARQL_ENDPOINT_URL = 'https://sparql.example.org/sparql'
    Rails.cache.clear
  end

  describe 'REST first' do
    it 'returns what the API gives it and never reaches SPARQL' do
      rest = OpenStruct.new('@id' => node, 'types' => [])
      allow(LinkedData::Client::HTTP).to receive(:get).and_return(rest)
      expect(Faraday).not_to receive(:new)

      expect(described_class.call('INRAETHES', node)).to eq(rest)
    end

    it 'falls through when the API answers with an error' do
      allow(LinkedData::Client::HTTP).to receive(:get).and_return(OpenStruct.new(errors: ['not found']))
      allow(Faraday).to receive(:new).and_return(instance_double(Faraday::Connection, get: sparql_response([])))

      expect(described_class.call('AGROVOC', node)).to be_nil
    end

    it 'falls through when the API raises' do
      allow(LinkedData::Client::HTTP).to receive(:get).and_raise(StandardError)
      allow(Faraday).to receive(:new).and_return(
        instance_double(Faraday::Connection, get: sparql_response([binding_for(value_predicate, 'Coastal areas…')]))
      )

      expect(described_class.call('AGROVOC', node)['@id']).to eq(node)
    end
  end

  describe 'the SPARQL fallback' do
    before { allow(LinkedData::Client::HTTP).to receive(:get).and_return(nil) }

    def with_bindings(bindings)
      allow(Faraday).to receive(:new).and_return(instance_double(Faraday::Connection, get: sparql_response(bindings)))
      described_class.call('AGROVOC', node)
    end

    it 'resolves an untyped node the REST endpoint cannot serve' do
      resource = with_bindings([binding_for(value_predicate, 'Coastal areas…'),
                                binding_for(source_predicate, 'FAO, 1998')])

      expect(resource['@id']).to eq(node)
      expect(resource[:properties].to_h[value_predicate.to_sym]).to eq(['Coastal areas…'])
      expect(resource[:properties].to_h[source_predicate.to_sym]).to eq(['FAO, 1998'])
    end

    it 'exposes the shape the instance view and the raw-data table read' do
      resource = with_bindings([binding_for(value_predicate, 'Coastal areas…')])

      expect(resource.types).to eq([])                       # untyped, and the view rejects on it
      expect(resource['label']).to eq([])                    # `.presence` falls through to prefLabel
      expect(resource[:properties].members).to eq([value_predicate.to_sym]) # ConceptDetailsComponent
    end

    it 'keeps several values of one predicate and drops duplicates' do
      resource = with_bindings([binding_for(value_predicate, 'one'),
                                binding_for(value_predicate, 'two'),
                                binding_for(value_predicate, 'one')])

      expect(resource[:properties].to_h[value_predicate.to_sym]).to eq(%w[one two])
    end

    it 'is nil when the node has no triples anywhere' do
      expect(with_bindings([])).to be_nil
    end

    it 'is nil when the endpoint fails' do
      allow(Faraday).to receive(:new).and_return(
        instance_double(Faraday::Connection, get: instance_double(Faraday::Response, success?: false, body: nil))
      )

      expect(described_class.call('AGROVOC', node)).to be_nil
    end

    it 'is nil when no SPARQL endpoint is configured' do
      $SPARQL_ENDPOINT_URL = nil
      expect(Faraday).not_to receive(:new)

      expect(described_class.call('AGROVOC', node)).to be_nil
    end
  end

  describe 'query safety' do
    before { allow(LinkedData::Client::HTTP).to receive(:get).and_return(nil) }

    # The URI is interpolated between angle brackets, so anything that could
    # close them must never reach the endpoint.
    it 'refuses a URI that could break out of the query' do
      expect(Faraday).not_to receive(:new)

      ['http://example.org/x> } ; DROP ALL ; SELECT * WHERE { <http://x',
       'http://example.org/a b',
       "http://example.org/\"x\"",
       'javascript:alert(1)',
       'urn:uuid:1234'].each do |unsafe|
        expect(described_class.call('AGROVOC', unsafe)).to be_nil
      end
    end

    it 'sends the subject URI bound in the query' do
      connection = instance_double(Faraday::Connection)
      allow(Faraday).to receive(:new).and_return(connection)
      expect(connection).to receive(:get) do |_url, params, _headers|
        expect(params[:query]).to eq("SELECT DISTINCT ?p ?o WHERE { <#{node}> ?p ?o }")
        sparql_response([binding_for(value_predicate, 'text')])
      end

      described_class.call('AGROVOC', node)
    end
  end

  describe 'caching' do
    # The test environment points MemCacheStore at a host that is not reachable
    # from the container, so it silently no-ops; these need a store that stores.
    before do
      allow(LinkedData::Client::HTTP).to receive(:get).and_return(nil)
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    end

    it 'queries once for repeated lookups of the same node' do
      connection = instance_double(Faraday::Connection)
      allow(Faraday).to receive(:new).and_return(connection)
      expect(connection).to receive(:get).once.and_return(sparql_response([binding_for(value_predicate, 'text')]))

      2.times { described_class.call('AGROVOC', node) }
    end

    it 'caches a miss, so an unresolvable node is not looked up on every render' do
      connection = instance_double(Faraday::Connection)
      allow(Faraday).to receive(:new).and_return(connection)
      expect(connection).to receive(:get).once.and_return(sparql_response([]))

      2.times { expect(described_class.call('AGROVOC', node)).to be_nil }
    end
  end

  it 'is nil without a URI' do
    expect(described_class.call('AGROVOC', nil)).to be_nil
    expect(described_class.call('AGROVOC', '')).to be_nil
  end
end
