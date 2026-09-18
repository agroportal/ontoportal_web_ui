# Converts an EntityGraphService graph into the VOWL JSON that WebVOWL reads
# (https://github.com/VisualDataWeb/WebVOWL, vendored under public/webvowl).
#
#   VowlOntologyService.call(graph, iri:, title:, description:, language:)
#     => { header:, namespace:, metrics:,
#          class: [{id, type}],    classAttribute:    [{id, iri, label, ...}],
#          property: [{id, type}], propertyAttribute: [{id, domain, range, ...}] }
#
# WebVOWL takes a whole ontology, converted from OWL by OWL2VOWL — a Java service
# fed the ontology file, which a portal ontology is far too big for (AGROVOC alone
# is hundreds of megabytes) and which we do not run. So it gets the selected
# class's neighbourhood instead, the same graph the Graph tab draws, already built
# and cached by EntityGraphService.
#
# What comes out describes that neighbourhood, not the ontology: the metrics count
# what is in the payload, and a portal class is published as owl:Class even when it
# is really a SKOS concept, because owl:Class is the only thing VOWL can draw it as.
class VowlOntologyService < ApplicationService
  # VOWL element types. WebVOWL lowercases both sides before matching them against
  # its element prototypes, so the spelling here only has to read well.
  CLASS_TYPE = 'owl:Class'.freeze
  ISA_TYPE = 'rdfs:SubClassOf'.freeze
  RELATION_TYPE = 'owl:ObjectProperty'.freeze

  # Graph edge kind standing for subClassOf; every other edge is an asserted
  # relationship.
  ISA_KIND = 'is-a'.freeze

  # WebVOWL looks a label up under the language the viewer picked, then under 'en',
  # then under this key. Labels here are already resolved to the request language,
  # so each one is published under both keys and stays readable whichever language
  # the viewer ends up on.
  FALLBACK_LANGUAGE = 'undefined'.freeze

  # Marks an asserted relationship as an object property, which is what VOWL draws
  # a labelled box on the link for.
  OBJECT_PROPERTY_ATTRIBUTE = 'object'.freeze

  # The sidebar lists one line per annotation, taking only the FIRST value of each,
  # so a class's synonyms travel as one joined line under one key rather than as
  # one key each.
  SYNONYM_ANNOTATION = 'synonym'.freeze
  SYNONYM_SEPARATOR = ', '.freeze

  def initialize(graph, iri:, title:, description: '', language: nil)
    @graph = graph || {}
    @iri = iri
    @title = title
    @description = description
    # The portal hands language tags around upper-cased ('EN'); VOWL and WebVOWL's
    # own default are lower-case, and the two only meet if we match them.
    @language = language.to_s.downcase.presence || FALLBACK_LANGUAGE
  end

  def call
    nodes = Array(@graph[:nodes])
    @ids = nodes.each_with_index.to_h { |node, index| [node[:id], index.to_s] }

    # An edge whose endpoints are not both in the payload would draw a link to
    # nowhere, so it is dropped rather than published half-resolved.
    edges = Array(@graph[:edges]).select { |edge| @ids[edge[:from]] && @ids[edge[:to]] }

    {
      header: header,
      namespace: [],
      metrics: metrics(nodes, edges),
      class: nodes.each_index.map { |index| { id: index.to_s, type: CLASS_TYPE } },
      classAttribute: nodes.each_with_index.map { |node, index| class_attribute(node, index) },
      property: edges.each_with_index.map { |edge, index| { id: index.to_s, type: type_of(edge) } },
      propertyAttribute: edges.each_with_index.map { |edge, index| property_attribute(edge, index) }
    }
  end

  private

  def header
    {
      languages: [@language, FALLBACK_LANGUAGE].uniq,
      title: in_language(@title),
      iri: @iri,
      description: in_language(@description)
    }
  end

  # Counts of what this payload holds. There are no datatypes or individuals in a
  # neighbourhood graph, so those are honestly zero rather than left out.
  def metrics(nodes, edges)
    object_properties = edges.count { |edge| !isa_edge?(edge) }

    {
      classCount: nodes.size,
      datatypeCount: 0,
      objectPropertyCount: object_properties,
      datatypePropertyCount: 0,
      propertyCount: edges.size,
      nodeCount: nodes.size,
      individualCount: 0
    }
  end

  def class_attribute(node, index)
    {
      id: index.to_s,
      iri: node[:id],
      baseIri: base_iri(node[:id]),
      label: in_language(node[:label].to_s),
      description: (in_language(node[:definition].to_s) if node[:definition].present?),
      annotations: synonym_annotation(node)
    }.compact
  end

  # VOWL draws subClassOf from the subclass to the superclass, which is the
  # direction the graph's is-a edges already run (from child, to parent). The
  # element carries its own "Subclass of" label and rdfs: IRI — WebVOWL ignores
  # anything we would set — so an is-a edge is domain and range and nothing else.
  def property_attribute(edge, index)
    attribute = { id: index.to_s, domain: @ids[edge[:from]], range: @ids[edge[:to]] }
    return attribute if isa_edge?(edge)

    attribute.merge(
      iri: edge[:prop_id],
      baseIri: base_iri(edge[:prop_id]),
      label: in_language(edge[:label].to_s),
      attributes: [OBJECT_PROPERTY_ATTRIBUTE]
    ).compact
  end

  def type_of(edge)
    isa_edge?(edge) ? ISA_TYPE : RELATION_TYPE
  end

  def isa_edge?(edge)
    edge[:kind].to_s == ISA_KIND
  end

  def synonym_annotation(node)
    synonyms = Array(node[:synonyms]).map(&:to_s).reject(&:blank?)
    return nil if synonyms.empty?

    {
      SYNONYM_ANNOTATION => [{
        identifier: SYNONYM_ANNOTATION,
        language: FALLBACK_LANGUAGE,
        value: synonyms.join(SYNONYM_SEPARATOR),
        type: 'label'
      }]
    }
  end

  def in_language(text)
    { @language => text.to_s, FALLBACK_LANGUAGE => text.to_s }
  end

  # The IRI without its local name, e.g. http://purl.obolibrary.org/obo/ for an OBO
  # term. WebVOWL shows it in the sidebar and tells apart classes from elsewhere by
  # it.
  def base_iri(iri)
    return nil if iri.blank?

    iri.to_s[/\A.*[#\/]/]
  end
end
