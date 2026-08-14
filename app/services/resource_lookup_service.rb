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

  # A reified node carries its own text under one of these, most specific
  # first. The API maps none of them: of a resource it names only rdf:type,
  # rdfs:label and skos:prefLabel, and leaves everything else undifferentiated
  # in `properties`. So what counts as the node's text is decided here, not
  # derived from the model. `rdf:value` covers all twelve vocabularies that
  # reify their definitions - see doc/reified-definitions-survey.md.
  VALUE_PREDICATES = %w[
    http://www.w3.org/1999/02/22-rdf-syntax-ns#value
    http://www.w3.org/2008/05/skos-xl#literalForm
    http://www.w3.org/2004/02/skos/core#definition
    http://www.w3.org/2004/02/skos/core#note
  ].freeze

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

  # +lang+ is the content language the resource is read in. 'all' - the default,
  # and what the raw-data modal wants - keeps every literal whatever its tag.
  def initialize(acronym, uri, lang: 'all')
    @acronym = acronym
    @uri = uri.to_s
    @lang = lang.to_s.presence || 'all'
  end

  # The text the node carries in +lang+, or nil when no source knows the node.
  # An empty list and nil are not the same answer and callers depend on the
  # difference: a node nothing resolves has to keep rendering as the identifier
  # it is, while one that resolves but holds no text here carries it in another
  # language.
  def self.values(acronym, uri, lang: 'all')
    new(acronym, uri, lang: lang).values
  end

  # The resource, or nil when neither source knows it.
  def call
    return nil if @uri.blank?

    rest_resource || sparql_resource
  end

  def values
    return nil if @uri.blank?

    cached("resource_values/#{@lang.downcase}/#{Digest::SHA1.hexdigest(@uri)}") do
      resource = call
      resource && text_of(resource)
    end
  end

  private

  # The first of VALUE_PREDICATES the node actually carries. Everything else it
  # holds is provenance, and stays where it came from.
  def text_of(resource)
    properties = resource[:properties].to_h.transform_keys(&:to_s)

    VALUE_PREDICATES.each do |predicate|
      values = Array(properties[predicate]).map(&:to_s).reject(&:blank?)
      return values if values.present?
    end

    []
  end

  def rest_resource
    resource = LinkedData::Client::HTTP.get("/ontologies/#{@acronym}/instances/#{CGI.escape(@uri)}",
                                            { include: 'all', lang: @lang })

    return nil if resource.nil?
    return nil if resource.respond_to?(:errors) && resource.errors.present?
    return nil if resource['@id'].blank?

    resource
  rescue StandardError
    nil
  end

  # Whether the node exists is read from the unfiltered bindings, so a node that
  # holds nothing in this language still resolves - to a resource with no text,
  # which is a different answer from not resolving at all.
  def sparql_resource
    bindings = cached_bindings
    return nil if bindings.blank?

    Resource.build(@uri, triples(bindings))
  end

  # Misses are cached too: a node no source can resolve is looked up once, not
  # on every render of every row that mentions it. The bindings are what is
  # cached rather than the triples they group into, because the language they
  # are filtered by is the caller's, not the node's - one query serves them all.
  def cached_bindings
    cached("resource_lookup/#{Digest::SHA1.hexdigest(@uri)}") { query_bindings }
  end

  # { "<predicate>" => ["<value>", ...] }, keeping only what this language
  # covers. A literal with no tag belongs to every language, and a URI - a type,
  # a relation - carries none at all, so both stay whatever is asked for.
  def triples(bindings)
    bindings.each_with_object({}) do |binding, out|
      next unless language_match?(binding[:lang])

      out[binding[:predicate]] ||= []
      out[binding[:predicate]] << binding[:value] unless out[binding[:predicate]].include?(binding[:value])
    end
  end

  def language_match?(lang)
    return true if lang.blank? || @lang.casecmp?('all')

    lang.to_s.split('-').first.casecmp?(@lang.split('-').first)
  end

  # [{ predicate:, value:, lang: }, ...] - the node's triples as the endpoint
  # returns them, language tags included.
  def query_bindings
    return [] if $SPARQL_ENDPOINT_URL.blank?
    return [] unless @uri.match?(SAFE_URI)

    body = sparql_get("SELECT DISTINCT ?p ?o WHERE { <#{@uri}> ?p ?o }")
    return [] if body.blank?

    bindings = JSON.parse(body).dig('results', 'bindings') || []
    bindings.filter_map do |binding|
      predicate = binding.dig('p', 'value')
      value = binding.dig('o', 'value')
      next if predicate.blank? || value.blank?

      { predicate: predicate, value: value, lang: binding.dig('o', 'xml:lang') }
    end
  rescue StandardError
    []
  end

  # A cache the app can lose: every miss falls back to computing the answer.
  def cached(key, &block)
    Rails.cache.fetch(key, expires_in: CACHE_TTL, &block)
  rescue StandardError
    block.call
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
