# Converts an EntityGraphService graph into the JSON the Ontology Playground embed
# widget reads (https://github.com/microsoft/Ontology-Playground, vendored under
# public/ontology-embed).
#
#   PlaygroundOntologyService.call(graph, name:, description:)
#     => { name:, description:,
#          entityTypes: [{id, name, description, properties, icon, color}],
#          relationships: [{id, name, from, to, cardinality}] }
#
# The widget takes a whole ontology, and a portal ontology is far too large to hand
# it — AGROVOC alone is hundreds of megabytes. So it gets the selected class's
# neighbourhood instead, the same graph the Graph tab draws, which is already built
# and cached by EntityGraphService.
class PlaygroundOntologyService < ApplicationService
  # Node fill by role. Fixed hex rather than the portal's theme variables: this
  # renders inside the widget's own canvas, which knows nothing of portal CSS, and
  # ontoportal_web_ui is shared by portals with different palettes.
  SELECTED_COLOR = '#0f766e'.freeze      # the class the page is about
  HIERARCHY_ROOT_COLOR = '#94a3b8'.freeze # a top of the hierarchy
  CLASS_COLOR = '#64748b'.freeze          # everything else

  # The widget prefixes this to a node's graph label. Empty because a portal class
  # has no icon to show, and an emoji on every node only adds noise.
  NODE_ICON = ''.freeze

  # is-a runs from many subclasses up to one superclass. Asserted object properties
  # carry no cardinality in the graph payload, so they claim none.
  ISA_CARDINALITY = 'many-to-one'.freeze
  RELATION_CARDINALITY = 'many-to-many'.freeze

  ISA_KIND = 'is-a'.freeze
  ISA_LABEL = 'is a'.freeze

  def initialize(graph, name:, description: '')
    @graph = graph || {}
    @name = name
    @description = description
  end

  def call
    nodes = Array(@graph[:nodes])
    @ids = build_id_map(nodes)

    {
      name: @name,
      description: @description,
      entityTypes: nodes.map { |node| entity_type(node) },
      relationships: Array(@graph[:edges]).each_with_index.map { |edge, i| relationship(edge, i) }
    }
  end

  private

  # An entity's id is the local name the widget mints its RDF class from
  # (baseUri + id), so handing it a full IRI produces
  # rdf:about="http://example.org/…/Http://purl.obolibrary.org/obo/…". Map each IRI
  # to its last segment instead, suffixed when two namespaces share one — the ids
  # also key the graph's nodes, so collisions would merge unrelated classes.
  def build_id_map(nodes)
    seen = Hash.new(0)
    nodes.each_with_object({}) do |node, map|
      name = local_name(node[:id])
      seen[name] += 1
      map[node[:id]] = seen[name] > 1 ? "#{name}_#{seen[name]}" : name
    end
  end

  def local_name(iri)
    segment = iri.to_s.split(%r{[#/]}).last.to_s.gsub(/[^A-Za-z0-9_]/, '_')
    segment.empty? ? 'class' : segment
  end

  def entity_type(node)
    {
      id: @ids[node[:id]],
      name: node[:label].to_s,
      description: node[:definition].to_s,
      properties: synonym_properties(node),
      icon: NODE_ICON,
      color: color_for(node)
    }
  end

  # The widget's property chips read "<name>: <type>". There are no datatype
  # properties in a neighbourhood graph, so the chips carry the class's synonyms
  # instead — `type` is the chip's right-hand label here, not an XSD datatype.
  def synonym_properties(node)
    Array(node[:synonyms]).map { |synonym| { name: synonym.to_s, type: 'synonym' } }
  end

  def color_for(node)
    return SELECTED_COLOR if node[:selected]
    return HIERARCHY_ROOT_COLOR if node[:hierarchyRoot]

    CLASS_COLOR
  end

  # Edge ids only have to be unique within the payload; the graph's own edges carry
  # no id, and (from, to, property) can repeat once labels are resolved.
  def relationship(edge, index)
    is_a = edge[:kind].to_s == ISA_KIND
    {
      id: "e#{index}",
      name: is_a ? ISA_LABEL : edge[:label].to_s,
      from: @ids[edge[:from]],
      to: @ids[edge[:to]],
      cardinality: is_a ? ISA_CARDINALITY : RELATION_CARDINALITY
    }
  end
end
