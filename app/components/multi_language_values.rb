# frozen_string_literal: true

# Normalizes the several shapes a multilingual concept value arrives in
# (prefLabel, synonym, definition, ...) into a flat list of
# <tt>{ text:, lang: }</tt> entries, with +lang+ nil when the value carries no
# language.
#
# Handled shapes:
#   * a String                         -> a single value
#   * an Array of Strings              -> values in the current content language
#   * a Hash / OpenStruct {lang => []} -> values grouped by language ("all languages" view)
module MultiLanguageValues
  private

  def normalize_multi_language(raw)
    raw = raw.to_h.reject { |k, _| %i[links context].include?(k) } if raw.is_a?(OpenStruct)

    case raw
    when String
      raw.blank? ? [] : [multi_language_value(raw, nil)]
    when Array
      raw.flat_map { |value| normalize_multi_language_value(value) }
    when Hash
      raw.flat_map { |lang, values| Array(values).map { |value| multi_language_value(value, lang) } }
    else
      raw.blank? ? [] : [multi_language_value(raw, nil)]
    end.reject { |v| v[:text].blank? }
  end

  # An array entry is usually a plain String, but the "all languages" view nests
  # a per-language hash inside the array.
  def normalize_multi_language_value(value)
    if value.is_a?(String)
      [multi_language_value(value, nil)]
    elsif value.respond_to?(:to_h)
      value.to_h.reject { |k, _| %i[links context].include?(k) }
           .flat_map { |lang, values| Array(values).map { |v| multi_language_value(v, lang) } }
    else
      [multi_language_value(value, nil)]
    end
  end

  def multi_language_value(text, lang)
    { text: text.to_s, lang: normalize_language_code(lang) }
  end

  def normalize_language_code(lang)
    code = lang.to_s.strip
    return nil if code.blank? || %w[none @none].include?(code.downcase)

    code
  end
end
