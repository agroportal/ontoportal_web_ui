# frozen_string_literal: true

# Renders a concept's definitions (ontoportal/ontoportal_web_ui#67).
#
# A concept exposes its definitions in two parallel attributes:
#
#   * +definition+   - the flat skos:definition list. A *simple* definition is a
#     plain literal (readable text). A *reified* definition (stored as its own
#     RDF node) appears here as a bare node URI.
#   * +definitionXl+ - the resolved reified nodes. Each node carries the
#     definition +value+ (its text) plus provenance: +source+, +created+,
#     +modified+. (Mirrors +prefLabelXl+ for SKOS-XL labels.)
#
# Rendering:
#   * Simple definition   -> plain, readable text, in the same colour as the
#     surrounding content and never styled like a link (the #67 fix).
#   * Reified definition  -> its text, a "Reified" badge, and the source/date
#     provenance the node carries.
#   * Reified node the API did *not* resolve (no matching +definitionXl+ entry)
#     -> a clearly-marked link to the node, as before.
#
# Nothing is ever synthesised: a field is shown only when the node actually
# carries it.
class DefinitionsComponent < ViewComponent::Base
  # A reified definition value in the flat list is a bare IRI (no whitespace);
  # definition *text* always contains whitespace.
  URI_RE = %r{\Ahttps?://\S+\z}.freeze

  # +definitions+      - the flat +definition+ list (String / Array / Hash).
  # +definition_nodes+ - the resolved +definitionXl+ nodes (Array of objects or
  #                      Hashes exposing #value / #source / #created / #modified
  #                      and an @id). Optional; falls back to URI-only rendering.
  def initialize(definitions:, definition_nodes: nil, id: nil)
    @definitions = definitions
    @definition_nodes = definition_nodes
    @id = id
  end

  def render?
    items.present?
  end

  # Each item is one of:
  #   { reified: false, text: "The science of ...", ... }              # simple
  #   { reified: true,  text: "...", uri:, sources: [..],
  #     created:, modified: }                                          # resolved
  #   { reified: true,  text: nil, uri: "http://.../note_1", ... }     # unresolved
  def items
    @items ||= build_items
  end

  # True when the definitions span more than one language, so each should carry
  # its own language tag (typically the "all languages" content mode).
  def show_language_tags?
    items # ensure @show_language_tags has been computed
    @show_language_tags
  end

  # A small language-code tag (e.g. "FR") for a definition, or nil when tags are
  # not being shown or the definition has no language. Matches the language
  # badge used elsewhere for multilingual fields (see #display_in_multiple_languages).
  def language_tag(item)
    return unless show_language_tags? && item[:lang].present?

    content_tag(:span, item[:lang].to_s.upcase, class: 'definition-lang badge badge-secondary')
  end

  # Human-readable date; falls back to the raw value when it can't be parsed, so
  # an unexpected format is shown verbatim rather than dropped.
  def human_date(value)
    l(Date.parse(value.to_s), format: :monthfull_day_year)
  rescue ArgumentError, TypeError
    value.to_s
  end

  # Short, human-oriented label for a reified node URI (its last path segment).
  def reified_label(uri)
    uri.to_s.split(%r{[#/]}).reject(&:empty?).last.presence || uri.to_s
  end

  private

  def build_items
    nodes = Array(@definition_nodes).filter_map { |node| reified_item(node) }
    by_uri = nodes.each_with_object({}) { |item, h| h[item[:uri]] = item if item[:uri] }

    used = {}
    listed = flatten(@definitions).filter_map do |value|
      text = value.to_s.strip
      next if text.empty?

      if text.match?(URI_RE)
        if (node = by_uri[text])
          used[text] = true
          node
        else
          reified_uri_item(text)
        end
      else
        { reified: false, uri: nil, text: text, sources: [], created: nil, modified: nil, lang: nil }
      end
    end

    # Any resolved node whose URI wasn't in the flat list (shouldn't normally
    # happen) is still appended, so nothing is silently dropped.
    orphans = nodes.reject { |item| item[:uri] && used[item[:uri]] }
    result = listed + orphans

    # Tag each definition with its language only when the definitions span more
    # than one language (i.e. the "all languages" content mode). With a single
    # language selected, that language is already the context, so a per-item tag
    # would just be noise.
    @show_language_tags = result.filter_map { |item| item[:lang] }.uniq.size > 1

    result
  end

  # Build a rich item from a resolved reified node (OpenStruct / Hash / object).
  def reified_item(node)
    attrs = node_hash(node)
    uri = presence(attrs[:"@id"], attrs[:id], attrs[:uri])
    text = presence(attrs[:value])
    sources = Array(attrs[:source]).map { |s| s.to_s.strip }.reject(&:empty?)
    created = presence(attrs[:created])
    modified = presence(attrs[:modified])
    lang = presence(attrs[:lang])

    return nil if uri.blank? && text.blank? && sources.empty?

    { reified: true, uri: uri, text: text, sources: sources,
      created: created, modified: modified, lang: lang }
  end

  def reified_uri_item(uri)
    { reified: true, uri: uri, text: nil, sources: [], created: nil, modified: nil, lang: nil }
  end

  # Normalise a node (OpenStruct from the API client, a Hash from tests, a bare
  # URI string, ...) to a symbol-keyed Hash. The @id key is preserved as :@id.
  def node_hash(node)
    case node
    when Hash then node.transform_keys(&:to_sym)
    when String then { :"@id" => node }
    else
      node.respond_to?(:to_h) ? node.to_h.transform_keys(&:to_sym) : {}
    end
  end

  def presence(*values)
    values.map { |v| v.is_a?(String) ? v.strip : v }.find(&:present?)
  end

  # Reduce the flat definition list (String / Array / Hash / object) to a flat
  # list of definition values (Strings). A reified entry stays a bare URI so it
  # can be matched against the resolved nodes.
  def flatten(value)
    case value
    when nil then []
    when String then [value]
    when Array then value.flat_map { |v| flatten(v) }
    when Hash then value.values.flat_map { |v| flatten(v) }
    else
      if value.respond_to?(:uri) && value.uri.present?
        [value.uri.to_s]
      elsif value.respond_to?(:to_h)
        flatten(value.to_h.reject { |k, _| %i[links context].include?(k) })
      else
        [value.to_s]
      end
    end
  end
end
