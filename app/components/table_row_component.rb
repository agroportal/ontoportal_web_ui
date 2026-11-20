# frozen_string_literal: true

class TableRowComponent < ViewComponent::Base

  renders_many :cells, TableCellComponent

  def initialize(id: '', class_css: '')
    super()
    @id = id
    @class_css = class_css
  end

  def create(*array, &block)
    array.each do |key_value|
      key, value = key_value.to_a.first
      self.with_cell(type: key) { value&.to_s }
    end
    block.call(self) if block_given?
  end

  # data: data-* attributes, e.g. DataTables' { orderable: false } on a header
  # or { order: '2024-01-31' }, the value it sorts a cell by
  def th(width: nil, colspan: nil, data: nil, &block)
    self.with_cell(type: 'th', width: width, colspan: colspan, data: data, &block)
  end

  def td(width: nil, colspan: nil, data: nil, &block)
    self.with_cell(type: 'td', width: width, colspan: colspan, data: data, &block)
  end
end
