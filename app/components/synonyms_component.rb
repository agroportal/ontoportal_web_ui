# frozen_string_literal: true

# Renders a concept's synonyms as compact, wrapping "chips".
#
# Synonyms are displayed close to (but visually distinct from) the preferred
# name: same nature (terms) with a different status (alternative labels). They
# are deliberately styled so they don't look like links or clickable objects.
#
# Accepts synonyms in any of the shapes the API / the rest of the app use:
#   * a String                        -> a single synonym
#   * an Array of Strings             -> synonyms in the current content language
#   * a Hash / OpenStruct {lang => []}-> synonyms grouped by language ("all languages" view)
#
# When there are more than +show_max+ synonyms, only the first +show_max+ chips
# are shown followed by a "+N" chip that opens an accessible modal dialog with
# the full list (keyboard operable: Enter / Space to open, Esc to close).
class SynonymsComponent < ViewComponent::Base
  include MultiLanguageValues

  def initialize(synonyms:, id: nil, show_max: 10)
    @synonyms = synonyms
    @show_max = show_max
    @id = id.presence || "synonyms-#{SecureRandom.hex(4)}"
  end

  def render?
    chips.present?
  end

  # [{ text: "Etiology", lang: "en" }, ...] ; lang is nil when language-agnostic
  def chips
    @chips ||= normalize_multi_language(@synonyms)
  end

  def visible_chips
    chips.first(@show_max)
  end

  def hidden_count
    [chips.size - @show_max, 0].max
  end

  def overflow?
    hidden_count.positive?
  end

  def modal_id
    "#{@id}-modal"
  end

  def title_id
    "#{@id}-title"
  end

  # Renders a single synonym chip: the term, and its language tag when known.
  def chip_tag(chip)
    text = tag.span(chip[:text], class: 'synonym-chip__text', lang: chip[:lang])
    lang = chip[:lang] ? tag.span(chip[:lang].upcase, class: 'synonym-chip__lang', 'aria-hidden': 'true') : nil

    tag.span(safe_join([text, lang].compact), class: 'synonym-chip')
  end

end
