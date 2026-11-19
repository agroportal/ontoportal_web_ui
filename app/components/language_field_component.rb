# frozen_string_literal: true
require 'iso-639'

class LanguageFieldComponent < ViewComponent::Base

  include FlagIconsRails::Rails::ViewHelpers, MultiLanguagesHelper

  def initialize(value:, label: nil, auto_label: false, icon: nil)
    super()
    @value = value
    @lang_code = nil
    @label = label
    @icon = icon
    @lang_code, label = find_language_code_name(value)
    @label ||= label if auto_label
    @lang_code = @lang_code.split('-').last if @lang_code
  end

  def lang_code
    case @lang_code
    when 'en' then @lang_code = 'gb'
    when 'ar' then @lang_code = 'sa'
    when 'hi' then @lang_code = 'in'
    when 'ur' then @lang_code = 'pk'
    when 'zh' then @lang_code = 'cn'
    when 'ja' then @lang_code = 'jp'
    when 'cs' then @lang_code = 'cz'
    when 'da' then @lang_code = 'dk'
    when 'el' then @lang_code = 'gr'
    when 'fa' then @lang_code = 'ir'
    when 'ka' then @lang_code = 'ge'
    when 'ko' then @lang_code = 'kr'
    when 'lo' then @lang_code = 'la'
    when 'sw' then @lang_code = 'ke'
    when 'te' then @lang_code = 'in'
    when 'uk' then @lang_code = 'ua'
    when 'af' then @lang_code = 'za'
    when 'am' then @lang_code = 'et'
    when 'bn' then @lang_code = 'bd'
    when 'ca' then @lang_code = 'es'
    when 'he' then @lang_code = 'il'
    when 'ms' then @lang_code = 'my'
    when 'sl' then @lang_code = 'si'
    when 'ta' then @lang_code = 'in'
    when 'vi' then @lang_code = 'vn'
    else @lang_code
    end
  end

  def value
    @value&.is_a?(String) ? @value.to_s.split('/').last : 'NO-LANG'
  end
end
