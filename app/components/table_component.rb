# frozen_string_literal: true

class TableComponent < ViewComponent::Base

  renders_one :header, TableRowComponent
  renders_many :rows, TableRowComponent

  def initialize(id: '', stripped: true, borderless: false, custom_class: '', layout_fixed: false,
                 small_text: false, outline: false, sort_column: nil,
                 paging: false, page_length: nil, show_all: false, all_label: nil,
                 searching: false, search_placeholder: nil,
                 no_init_sort: false, server_side: false, ajax_url: nil, columns: [], ordering: true)
    super()
    @id = id
    @stripped = stripped
    @borderless = borderless
    @layout_fixed = layout_fixed
    @small_text = small_text
    @outline = outline
    @sort_column = sort_column
    @searching = searching
    @paging = paging
    @page_length = page_length
    @show_all = show_all
    @all_label = all_label || I18n.t('table.all', default: 'All')
    @no_init_sort = no_init_sort
    @custom_class = custom_class
    @search_placeholder = search_placeholder
    @server_side = server_side
    @ajax_url = ajax_url
    @columns = columns
    @ordering = ordering

  end

  def stripped_class
    @stripped ? 'table-content-stripped' : ''
  end

  def borderless_class
    @borderless ? 'table-content-borderless' : ''
  end

  def layout_fixed_class
    @layout_fixed ? 'table-layout-fixed' : 'table-auto-layout'
  end

  def add_row(*array, &block)
    self.row.create(*array, &block)
  end

  def mini_class
    @small_text ? 'table-mini' : ''
  end

  def outline_class
    @outline ? 'table-outline' : ''
  end
end
