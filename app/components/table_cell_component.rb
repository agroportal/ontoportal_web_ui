# frozen_string_literal: true

class TableCellComponent < ViewComponent::Base

  def initialize(width: nil, colspan: nil,type: 'td', data: nil)
    super()
    @width = width
    @type = type
    @colspan = colspan
    @data = data
  end

  def call
    options = {}
    options[:width] = @width if @width
    options[:colspan] = @colspan if @colspan
    options[:data] = @data if @data
    content_tag(@type, content&.html_safe, options)
  end
end
