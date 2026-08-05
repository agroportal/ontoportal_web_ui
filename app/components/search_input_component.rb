# frozen_string_literal: true

class SearchInputComponent < ViewComponent::Base

  renders_one :template

  def initialize(id: '',
                 name: '', placeholder: '', actions_links: {},
                 scroll_down: true, use_cache: true,
                 ajax_url:,
                 item_base_url:,
                 id_key:,
                 links_target: '_top',
                 search_icon_type: nil,
                 display_all: false,
                 sections: [])
    @sections = sections
    @id = id
    @name = name
    @placeholder = placeholder
    @actions_links = actions_links
    @use_cache = use_cache
    @scroll_down = scroll_down
    @ajax_url = ajax_url
    @item_base_url = item_base_url
    @id_key = id_key
    @links_target = links_target
    @search_icon_type = search_icon_type
    @display_all = display_all
  end
  def action_link_info(value)
    if value.is_a?(Hash)
       [value[:link] , value[:target]]
    else
      [value, '_top']
    end
  end
  def nav_icon_class
    @search_icon_type.eql?('nav') ? 'search-input-nav-icon' : ''
  end
  def display_all_mode_class
    classes = []
    classes << 'search-container-scroll' if @display_all
    # Three headed sections need more room than a single flat list before the
    # last one falls below the fold.
    classes << 'search-container-sections' if Array(@sections).any?
    classes.join(' ')
  end

  # Ordered [{key:, label:, limit:}] groups. Results carrying a matching `group`
  # key are rendered under a heading, in this order, at most `limit` of them
  # (omit it for no cap). Left empty the dropdown keeps its flat, unheaded
  # layout.
  def sections_value
    Array(@sections).map do |s|
      { key: s[:key].to_s, label: s[:label].to_s, limit: s[:limit]&.to_i }
    end.to_json
  end
end
