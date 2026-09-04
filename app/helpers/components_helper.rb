module ComponentsHelper
  include TermsReuses

  def dropdown_component(id: ,title: nil, tooltip:nil , is_open: false, &block)
    render DropdownContainerComponent.new(id: id, title: title, tooltip: tooltip, is_open: is_open) do |d|
      capture(d, &block) if block_given?
    end
  end

  def portal_button(name: nil , color: nil , light_color: nil, link: nil, tooltip: nil)
    render FederatedPortalButtonComponent.new(name: name, color: color, link: link, tooltip: tooltip, light_color: light_color)
  end

  def tab_item_component(container_tabs:, title:, path:, id: nil, selected: false, json_link: "", &content)
    container_tabs.item(id: id, title: title.html_safe, path: path, selected: selected, json_link: json_link)
    container_tabs.item_content { capture(&content) }
  end

  def alert_component(message, type: "info")
    render Display::AlertComponent.new(type: type, message: message)
  end

  def chips_component(id: , name: , label: , value: , checked: false , tooltip: nil, disabled: false, &block)
    content_tag(:div, data: { controller: 'tooltip' }, title: tooltip) do
      check_input(id: id, name: name, value: value, label: label, checked: checked, disabled: disabled, &block)
    end
  end
  def list_items_component(max_items:, &block)
    render ListItemsShowMoreComponent.new(max_items: max_items) do |r|
      capture(r, &block)
    end
  end

  def group_chip_component(id: nil, name: , object: , checked: , value: nil, title: nil, disabled: false, &block)
    title ||= object["name"]
    value ||= (object["value"] || object["acronym"] || object["id"])

    chips_component(id: id || value, name: name, label: object["acronym"],
                    checked: checked,
                    value: value, tooltip: title, disabled: disabled, &block)
  end
  alias  :category_chip_component :group_chip_component

  def rdf_highlighter_container(format, content)
    render Display::RdfHighlighterComponent.new(format: format, text: content)
  end

  def check_resolvability_container(url)
    turbo_frame_tag("#{escape(url)}_container", src: "/check_url_resolvability?url=#{escape(url)}", loading: "lazy", class: 'd-inline-block') do
      content_tag(:div, class: 'p-1', data: { controller: 'tooltip' }, title: t('components.check_resolvability')) do
        render LoaderComponent.new(small: true)
      end
    end
  end

  def search_page_input_component(name:, value: nil, placeholder: , button_icon: 'icons/search.svg', type: 'text', &block)
    content_tag :div, class: 'search-page-input-container', data: { controller: 'reveal' } do
      search_input = content_tag :div, class: 'search-page-input' do
        concat text_field_tag(name, value, type: type, placeholder: placeholder)
        concat(content_tag(:div, class: 'search-page-button') do
          render Buttons::RegularButtonComponent.new(id:'search-page-button', value: "Search", variant: "primary", type: "submit") do |btn|
            btn.icon_right { inline_svg_tag button_icon}
          end
        end)
      end

      options = block_given? ?  capture(&block) : ''

      (search_input + options).html_safe
    end
  end

  def paginated_list_component(id:, results:, next_page_url:, child_url:, child_turbo_frame:, child_param:, open_in_modal: false , selected: nil, auto_click: false, submission: nil)
    render(TreeInfiniteScrollComponent.new(
      id:  id,
      collection: results.collection,
      next_url: next_page_url,
      current_page: results.page,
      next_page: results.nextPage,
      auto_click: auto_click,
    )) do |c|
      if results.page.eql?(1)
        concat(content_tag(:div, class: 'ontologies-selector-results') do
          content_tag(:div, class: 'results-number small ml-2') do
            "#{t('ontologies.showing')} #{results.totalCount}".html_safe
          end
        end)
      end

      concepts = c.collection
      if concepts && !concepts.empty?
        concepts.each do |concept|
          concept.id = concept["@id"] unless concept.id
          data = {  child_param => concept.id }
          href = child_url.include?('?') ? "#{child_url}&id=#{escape(concept.id)}" : "#{child_url}?id=#{escape(concept.id)}"
          concat(render(TreeLinkComponent.new(
            child: concept,
            href: href,
            children_href: '#',
            selected: selected.blank? ? false : concept.id.eql?(selected) ,
            target_frame: child_turbo_frame,
            data: data,
            open_in_modal: open_in_modal,
            is_reused: concept_reused?(submission: submission, concept_id: concept.id)
          )))
        end
      end
      c.error do
        t('components.tree_view_empty')
      end
    end
  end

  def resolvability_check_tag(url)
    content_tag(:span, check_resolvability_container(url),  class: 'resolvability-check',style: 'display: inline-block;', onClick: "window.open('#{check_resolvability_url(url: url)}', '_blank');")
  end

  def rounded_button_component(link)
    link, target = api_button_link_and_target(link)
    render RoundedButtonComponent.new(link: link, target: target, size: 'small', title: t("components.go_to_api"))
  end

  def copy_link_to_clipboard(url, show_content: false)
    content_tag(:span, style: 'display: inline-block;') do
      render ClipboardComponent.new(title: t("components.copy_original_uri"), message: url, show_content: show_content)
    end
  end

  def generated_link_to_clipboard(url, acronym)
    url = "#{$UI_URL}/ontologies/#{acronym}/#{link_last_part(url)}"
    content_tag(:span, id: "generate_portal_link", style: 'display: inline-block;') do
      render ClipboardComponent.new(icon: 'icons/copy_link.svg', title: "#{t("components.copy_portal_uri", portal_name: portal_name)} #{link_to(url)}", message: url, show_content: false)
    end
  end

  def htaccess_tag(acronym)
    content_tag(:span, 'data-controller': 'tooltip', style: 'display: inline-block; width: 18px;', title: "See #{t("ontologies.htaccess_modal_title", acronym: acronym)}") do
      link_to_modal(nil, "/ontologies/#{acronym}/htaccess", data: {show_modal_title_value: "#{t("ontologies.htaccess_modal_title", acronym: acronym)}", show_modal_size_value: 'modal-xl'}) do
        inline_svg_tag("icons/copy_link.svg")
      end
    end
  end

  def link_to_with_actions(link_to_tag, acronym: nil, url: nil, copy: true, check_resolvability: true, generate_link: true, generate_htaccess: false)
    tag = link_to_tag
    url = link_to_tag if url.nil?

    tag += content_tag(:span, class: 'mx-1') do
      concat copy_link_to_clipboard(url) if copy
      concat generated_link_to_clipboard(url, acronym) if generate_link
      concat resolvability_check_tag(url) if check_resolvability
      concat htaccess_tag(acronym) if generate_htaccess
    end

    tag.html_safe
  end

  def tree_component(root, selected, target_frame:, sub_tree: false, id: nil, auto_click: false, submission: nil, &child_data_generator)
    root.children.sort! { |a, b| (a.prefLabel || a.id).downcase <=> (b.prefLabel || b.id).downcase }

    render TreeViewComponent.new(id: id, sub_tree: sub_tree, auto_click: auto_click) do |tree_child|
      root.children.each do |child|
        children_link, data, href = child_data_generator.call(child)

        if children_link.nil? || data.nil? || href.nil?
          raise ArgumentError, t('components.error_block')
        end

        tree_child.child(child: child, href: href,
                         children_href: children_link, selected: child.id.eql?(selected&.id),
                         muted: child.isInActiveScheme&.empty?,
                         target_frame: target_frame,
                         data: data, is_reused: concept_reused?(submission: submission, concept_id: child.id)) do
          tree_component(child, selected, target_frame: target_frame, sub_tree: true,
                         id: id, auto_click: auto_click, submission: submission, &child_data_generator)
        end
      end
    end
  end

  def ajax_link_chip(id, label = nil, link = nil, external: false, open_in_modal: false, ajax_src: nil, target: '_blank')
    render LabelFetcherComponent.new(id: id, label: label, link: link, open_in_modal: open_in_modal, ajax_src: ajax_src, target: target, external: external)
  end

  def chart_component(title: '', type:, labels:, datasets:, index_axis: 'x', show_legend: false)
    data = {
      controller: 'load-chart',
      'load-chart-type-value': type,
      'load-chart-title-value': title,
      'load-chart-labels-value': labels,
      'load-chart-index-axis-value': index_axis,
      'load-chart-datasets-value': datasets,
      'load-chart-legend-value': show_legend,
    }
    content_tag(:canvas, nil, data: data)
  end

  def loader_component(type:'pulsing', small: false )
    render LoaderComponent.new(type: type, small: small)
  end

  def info_tooltip(text, interactive: true)
    render Display::InfoTooltipComponent.new(text: text, interactive: interactive)
  end

  def empty_state_message(message)
    content_tag(:p, message.html_safe, class: 'font-italic field-description_text')
  end

  def properties_list_component(c, properties, truncate: true, &block)
    properties.each do |k, value|
      values, label = value
      c.row do
        content = if block_given?
                    capture(values, &block)
                  else
                    if Array(values).any?{|v| link?(v)}
                      horizontal_list_container(values, truncate: truncate) { |v| link?(v) ? render(LinkFieldComponent.new(value: v)) : v }
                    else
                      Array(values).join(', ')
                    end
                  end
        render FieldContainerComponent.new(label: attr_label(k, label, attr_metadata: attr_metadata(k.to_s), show_tooltip: false), value: content.to_s.html_safe)
      end
    end

  end

  def horizontal_list_container(values, truncate: true, &block)
    return if Array(values).empty?

    render Layout::HorizontalListComponent.new(truncate: truncate) do |l|
      Array(values).each do |v|
        l.element do
          capture(v, &block)
        end
      end
    end
  end

  def list_container(values, &block)
    return if Array(values).empty?

    render Layout::ListComponent.new do |l|
      Array(values).each do |v|
        l.row do
          capture(v, &block)
        end
      end
    end
  end

  def properties_card(title, tooltip, properties, &block)
    render Layout::CardComponent.new do |d|
      d.header(text: title, tooltip: tooltip)
      render(Layout::ListComponent.new) do |c|
        if properties
          properties_list_component(c, properties, &block)
        else
          capture(c, &block)
        end
      end
    end
  end

  def properties_dropdown(id, title, tooltip, properties, is_open: false, &block)
    render DropdownContainerComponent.new(title: title, id: id, tooltip: tooltip, is_open: is_open) do |d|
      d.empty_state do
        properties_string = properties.keys[0..4].map { |key| "<b>#{attr_label(key, attr_metadata: attr_metadata(key), show_tooltip: false)}</b>" }.join(', ') + '... ' if properties
        empty_state_message t('components.empty_field', properties: properties_string)
      end

      render Layout::ListComponent.new do |c|
        if properties
          properties_list_component(c, properties, &block)
        else
          capture(c, &block)
        end
      end
    end
  end

  def regular_button(id, value, variant: "secondary", state: "regular", size: "slim", href: nil, &block)
    render Buttons::RegularButtonComponent.new(id:id, value: value, variant: variant, state: state, size: size, href: href) do |btn|
      capture(btn, &block) if block_given?
    end
  end

  def form_save_button(enable_loading: true)
    render Buttons::RegularButtonComponent.new(id: 'save-button', value: t('components.save_button'), variant: "primary", size: "slim", type: "submit", state: enable_loading ? 'animate' : '') do |btn|
      btn.icon_left do
        inline_svg_tag "check.svg"
      end
    end
  end

  def form_cancel_button
    render Buttons::RegularButtonComponent.new(id: 'cancel-button', value: t('components.cancel_button'), variant: "secondary", size: "slim") do |btn|
      btn.icon_left do
        inline_svg_tag "x.svg", width: "9", height: "9"
      end
    end
  end

  def text_with_icon(text:, icon:)
    content_tag(:div, class: 'd-flex align-items-center icon') do
      inline_svg_tag(icon, height: '18', weight: '18') + content_tag(:div, class: 'text') {text}
    end
  end
end
