# frozen_string_literal: true

# Renders a concept's definitions as plain, readable prose.
#
# A definition is the primary content of a concept page, so it is set as normal
# upright text in the surrounding colour: never italic (hard to read over a
# whole paragraph), and never portal-coloured on a tinted background (it failed
# WCAG AA contrast on every theme and read as a link that could not be clicked).
# The "Definitions" row label carries the meaning, so the text does not have to.
#
# Accepts definitions in any of the shapes the API / the rest of the app use:
#   * a String                         -> a single definition
#   * an Array of Strings              -> definitions in the current content language
#   * a Hash / OpenStruct {lang => []} -> definitions grouped by language ("all languages" view)
#
# A value that is a URI is *not* a definition: it points at a reified node that
# holds the text, its source and its dates. Given +acronym+, each such node is
# resolved and folded back into the prose - see #items for what that means row
# by row. Without one, the URI is left as the identifier it is, and inert.
class DefinitionsComponent < ViewComponent::Base
  include MultiLanguageValues
  include ModalHelper
  include ResourceLinksHelper
  include UrlsHelper

  # Past this many characters a definition is cropped, and read on through the
  # app's own read-more control. The clamp is what decides whether that control
  # ever shows itself - a definition that fits stays whole either way - so this
  # only decides which definitions are worth restructuring the row for: a short
  # one keeps its badge and icon on the line it ends, where they read as part of
  # the sentence.
  CROP_AFTER = 240

  # How far a reified node is chased.
  #
  #   :full    - every node is looked up, folded into the text it holds and left
  #              with a way through to its raw data. What a resource's own page
  #              wants: the definition, and the provenance behind it.
  #   :summary - a node whose text the row already carries is dropped where it
  #              stands, and only a node that would leave the row empty costs a
  #              request. What a page of search results wants: the sentence, and
  #              no lookup per result to read it.
  LOOKUP_FULL = :full
  LOOKUP_SUMMARY = :summary

  # +parent_uri+ is the resource these definitions were read from: a node minted
  # by another vocabulary cannot belong to this ontology, and is not looked up.
  # +lang+ is the content language the page is being read in, and the one a node
  # is resolved in - a node holding only French is not an English definition.
  def initialize(definitions:, id: nil, acronym: nil, parent_uri: nil, lang: 'all', lookup: LOOKUP_FULL)
    @definitions = definitions
    @acronym = acronym
    @parent_uri = parent_uri
    @lang = lang
    @lookup = lookup
    @id = id.presence || "definitions-#{SecureRandom.hex(4)}"
  end

  def render?
    items.present?
  end

  # [{ text: "A parasitic disease ...", lang: "en", node: nil }, ...] ; lang is
  # nil when the definition carries no language (the single-language view), and
  # node is the URI of the reified node the text was read from, when there is
  # one.
  #
  # Every URI in the list is resolved, and what comes back decides the row:
  #
  #   * the node's text is already in the list -> the URI drops out, and the
  #     text it duplicates gains the link to the node's raw data;
  #   * the node's text is not in the list -> it is shown in place of the URI,
  #     with that same link (the submission was parsed before the text was
  #     extracted, so the node is all there is);
  #   * the node holds no text in this language -> it drops out, and stays
  #     visible under "all languages";
  #   * no source knows the node -> its identifier stays, inert, because
  #     nothing better is known about it.
  def items
    @items ||= resolve_nodes(normalize_multi_language(@definitions))
  end

  # The language is spelled out for sighted users as a small neutral badge; a
  # screen reader gets it from the paragraph's +lang+ attribute instead, which
  # is what makes it read a French definition with a French voice.
  def language_tag(item)
    return if item[:lang].blank?

    tag.span(item[:lang].upcase, class: 'badge badge-secondary definition-lang', 'aria-hidden': 'true')
  end

  # A reified definition nothing could resolve: the node's identifier, shown as
  # an identifier rather than as a sentence, and not clickable.
  def definition_uri(item)
    tag.span(item[:text], class: 'definition-uri')
  end

  # A definition long enough to swamp the row, cropped to three lines. Some
  # vocabularies write a paragraph where others write a sentence, and six of
  # those under "all languages" bury everything below them.
  def cropped?(item)
    item[:text].to_s.length > CROP_AFTER
  end

  # What trails the sentence - the language it is written in, the node it was
  # read from - kept on one line: split by a wrap, a lone badge or a lone icon
  # reads as a stray mark belonging to nothing.
  def definition_meta(item)
    meta = safe_join([language_tag(item), raw_data_link(item)].compact)
    return if meta.blank?

    tag.span(meta, class: 'definition-meta')
  end

  # The node the text was read from, opened as the triples it holds - its
  # source, its dates, everything a sentence cannot carry. Marked with the icon
  # every other link that opens a modal carries, at the size PopupLinkTextComponent
  # sets, so it reads as the one thing it is wherever it turns up.
  def raw_data_link(item)
    return if item[:node].blank?

    link_to_modal(nil, resource_modal_path(@acronym, item[:node]),
                  class: 'definition-raw-data', data: {},
                  title: t('definitions.raw_data'), 'aria-label': t('definitions.raw_data')) do
      inline_svg_tag('icons/popup-link.svg', width: '14px', height: '14px')
    end
  end

  private

  def resolve_nodes(items)
    nodes, texts = items.partition { |item| link?(item[:text]) }
    return items if nodes.empty?

    # The row already reads as prose, and under :summary that is all it owes the
    # reader. Which sentence was read from which node is worth a request on the
    # resource's own page and not on a page of a hundred and fifty others - and
    # a URI is no sentence whatever ontology it came from, so this holds without
    # one to resolve it against.
    return texts if summary? && texts.present?
    return items if @acronym.blank?

    texts + nodes.flat_map { |node| fold_in(node, texts) }
  end

  def summary?
    @lookup == LOOKUP_SUMMARY
  end

  # Folds one reified node into +texts+, returning what is left to render of it.
  def fold_in(node, texts)
    values = ResourceLookupService.values(@acronym, node[:text], lang: @lang) if reified?(node[:text])

    # A node that resolves to no text is read as a definition written in some
    # other language, and left to the "all languages" view. Under that view
    # there is no other language for it to be left to: it is a node nothing
    # could read, and dropping it would lose a definition the resource holds.
    return [node] if values.nil? || (values.empty? && all_languages?)

    values.filter_map do |value|
      shown = texts.find { |text| same_text?(text[:text], value[:text]) }
      next node.merge(text: value[:text], lang: node_language(value, node), node: node[:text]) if shown.nil?

      shown[:node] ||= node[:text]
      nil
    end
  end

  # A node carries no language of its own - the literal inside it does - so the
  # tag comes from the text that was read out of it. Worth naming only when
  # every language was asked for: under one, the whole row is in it and the app
  # names it nowhere.
  def node_language(value, node)
    all_languages? ? value[:lang] : node[:lang]
  end

  def all_languages?
    @lang.to_s.casecmp?('all')
  end

  # Worth a lookup: a URI minted by this ontology. One borrowed from another
  # vocabulary - a definition pointing at a term, a plain URL typed into the
  # field - is no node of ours, and the API would 404 on it.
  def reified?(uri)
    same_namespace?(uri, @parent_uri)
  end

  # The parser wrote the literal from the node, so whitespace and case aside the
  # two are the same text.
  def same_text?(one, other)
    normalize_text(one) == normalize_text(other)
  end

  def normalize_text(text)
    text.to_s.strip.gsub(/\s+/, ' ').downcase
  end
end
