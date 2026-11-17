# frozen_string_literal: true

class TabItemComponent < ViewComponent::Base

  include ActionView::Helpers::UrlHelper

  def initialize(id: nil, title: nil, path: nil, page_name: '', selected: false, json_link: nil, actions: nil)
    super()
    @id = id
    @title = title
    @path = path
    @page_name = page_name
    @selected = selected
    @json_link = json_link
    @actions = actions
  end

  def selected_item?
    @selected
  end

  def item_id
    id.parameterize.underscore
  end

  def target_id
    "#{item_id}_content"
  end


  def id
    @id || @title
  end

  def title
    @title
  end

  def active_class
    selected_item? ? 'active show' : ''
  end

  def page_name
    @page_name
  end

  def call
    link = link_to(@path, id: "#{item_id}_tab", class: "#{active_class} tab-link", 'data-json-link': @json_link) do
      (title && !title.empty?) ? title.html_safe : content
    end

    if @actions
      content_tag(:div, class: "d-flex align-items-center justify-content-between w-100") do
        concat(link)
        concat(content_tag(:div, @actions, onclick: "event.stopPropagation();", class: "ml-2"))
      end
    else
      link
    end
  end

end
