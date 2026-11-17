# frozen_string_literal: true

class Display::ImageComponent < ViewComponent::Base
  include ModalHelper

  def initialize(src: , title: '', enable_zoom: true)
    super()
    @src = src
    @title = title
    @enable_zoom = enable_zoom
  end

  def call
    content_tag(:div, class: 'image-container ') do
      depiction_with_modal(@src)
    end
  end

  def depiction_with_modal(depiction_url)
    img_tag = image_tag(depiction_url, class: 'image-content')
    loop_icon_tag = content_tag(:span , inline_svg_tag('icons/loop.svg'), class: 'loop_icon')
    modal_url = "/ajax/images/show?url=#{depiction_url}"
    modal_options = { data: { show_modal_title_value: @title, show_modal_size_value: 'modal-xl' } }

    if @enable_zoom
      link_to_modal(nil, modal_url, modal_options) do
        loop_icon_tag + img_tag
      end
    else
      img_tag
    end

  end
end
