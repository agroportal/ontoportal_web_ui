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
# holds the text. Setting one as prose dresses a URL up as a sentence, so it is
# marked as the identifier it is - and left inert. Following it, and reading
# what the node holds, is the raw-data table's job.
class DefinitionsComponent < ViewComponent::Base
  include MultiLanguageValues
  include UrlsHelper

  def initialize(definitions:, id: nil)
    @definitions = definitions
    @id = id.presence || "definitions-#{SecureRandom.hex(4)}"
  end

  def render?
    items.present?
  end

  # [{ text: "A parasitic disease ...", lang: "en" }, ...] ; lang is nil when
  # the definition carries no language (the single-language view).
  def items
    @items ||= normalize_multi_language(@definitions)
  end

  # The language is spelled out for sighted users as a small neutral badge; a
  # screen reader gets it from the paragraph's +lang+ attribute instead, which
  # is what makes it read a French definition with a French voice.
  def language_tag(item)
    return if item[:lang].blank?

    tag.span(item[:lang].upcase, class: 'badge badge-secondary definition-lang', 'aria-hidden': 'true')
  end

  # A reified definition: the node's identifier, shown as an identifier rather
  # than as a sentence, and not clickable - nothing in this row is.
  def definition_uri(item)
    tag.span(item[:text], class: 'definition-uri')
  end
end
