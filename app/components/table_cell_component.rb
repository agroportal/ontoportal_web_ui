# frozen_string_literal: true

class TableCellComponent < ViewComponent::Base

  def initialize(width: nil, colspan: nil,type: 'td')
    super()
    @width = width
    @type = type
    @colspan = colspan
  end

  def call
    options = {}
    options[:width] = @width if @width
    options[:colspan] = @colspan if @colspan
    content_tag(@type, content&.html_safe, options)
  end
end
