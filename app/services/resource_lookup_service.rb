# frozen_string_literal: true

require 'cgi'

# Resolves an RDF resource - typically a reified definition node - to the
# triples it holds.
#
# The REST API can only serve a resource it has a model for: `instances/:uri`
# needs `rdf:type owl:NamedIndividual`. Six of the twelve AgroPortal
# vocabularies that reify their definitions leave those nodes untyped, so about
# 33,000 definitions - AGROVOC's among them - are invisible to every typed
# endpoint the API exposes. That is structural, not a bug: there is no model to
# serve them under. See doc/reified-definitions-survey.md.
#
# SPARQL has no such requirement, so it answers for a node whatever its type.
# It is used strictly as a fallback - REST first, because it is cheaper and
# returns the API's own view of the resource - and it widens coverage without
# guaranteeing it: an ontology absent from the SPARQL store still resolves only
# if another one shares the node's URI.
class ResourceLookupService < ApplicationService
  RDF_TYPE       = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'
  RDFS_LABEL     = 'http://www.w3.org/2000/01/rdf-schema#label'
  SKOS_PREFLABEL = 'http://www.w3.org/2004/02/skos/core#prefLabel'

  CACHE_TTL = 1.hour
  QUERY_TIMEOUT = 8

  # The URI is interpolated into the query between angle brackets, so anything
  # that could close them - or smuggle in another clause - is refused outright
  # rather than escaped.
  SAFE_URI = %r{\Ahttps?://[^\s<>"'`\\{}|^]+\z}

  # Quacks like the struct the API client builds for an instance, so the views
  # and components render a resource the same way whichever source it came from.
  # +members+ is what ConceptDetailsComponent reads to list the raw triples.
  class Resource < OpenStruct
    def members
      to_h.keys
    end

    def self.build(uri, triples)
      new('@id' => uri,
          '@type' => Array(triples[RDF_TYPE]).first,
          'types' => Array(triples[RDF_TYPE]),
          'label' => Array(triples[RDFS_LABEL]),
          'prefLabel' => Array(triples[SKOS_PREFLABEL]).first,
          'properties' => new(triples))
    end
  end

  def initialize(acronym, uri)
    @acronym = acronym
    @uri = uri.to_s
  end

  # The resource, or nil when neither source knows it.
  def call
    return nil if @uri.blank?

    rest_resource || sparql_resource
  end

  private

  def rest_resource
    resource = LinkedData::Client::HTTP.get("/ontologies/#{@acronym}/instances/#{CGI.escape(@uri)}",
                                            { include: 'all', lang: 'all' })

    return nil if resource.nil?
    return nil if resource.respond_to?(:errors) && resource.errors.present?
    return nil if resource['@id'].blank?

    resource
  rescue StandardError
    nil
  end

  def sparql_resource
    triples = cached_triples
    return nil if triples.blank?

    Resource.build(@uri, triples)
  end

  # Misses are cached too: a node no source can resolve is looked up once, not
  # on every render of every row that mentions it.
  def cached_triples
    Rails.cache.fetch("resource_lookup/#{Digest::SHA1.hexdigest(@uri)}", expires_in: CACHE_TTL) do
      query_triples
    end
  rescue StandardError
    query_triples
  end

  # { "<predicate>" => ["<value>", ...] }
  def query_triples
    return {} if $SPARQL_ENDPOINT_URL.blank?
    return {} unless @uri.match?(SAFE_URI)

    body = sparql_get("SELECT DISTINCT ?p ?o WHERE { <#{@uri}> ?p ?o }")
    return {} if body.blank?

    bindings = JSON.parse(body).dig('results', 'bindings') || []
    bindings.each_with_object({}) do |binding, out|
      predicate = binding.dig('p', 'value')
      value = binding.dig('o', 'value')
      next if predicate.blank? || value.blank?

      out[predicate] ||= []
      out[predicate] << value unless out[predicate].include?(value)
    end
  rescue StandardError
    {}
  end

  def sparql_get(query)
    connection = Faraday.new { |c| c.options.timeout = QUERY_TIMEOUT }
    response = connection.get($SPARQL_ENDPOINT_URL, { query: query },
                              { 'Accept' => 'application/sparql-results+json' })

    response.success? ? response.body : nil
  rescue StandardError
    nil
  end
end
