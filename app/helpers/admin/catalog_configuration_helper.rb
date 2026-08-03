module Admin::CatalogConfigurationHelper

  def description_tooltip(label, description, show_tooltip: true)
    return '' if description.nil? || description.empty?
    content_tag(:div) do
      tooltip_span = render(Display::InfoTooltipComponent.new(text: description_tooltip_help_text(label, description)))
      html = content_tag(:span, tooltip_span, class: 'ml-1') if show_tooltip
      html
    end
  end
  
  def attr_metadata_header_label(attr, label = nil, show_tooltip: true)
    label ||= attr.label
    return '' if label.nil? || label.empty?

    content_tag(:div) do
      tooltip_span = render(Display::InfoTooltipComponent.new(text: attribute_metdata_help_text(attr)))
      html = content_tag(:span, label)
      html += content_tag(:span, '*', class: "text-danger") if attr.required?
      html += content_tag(:span, tooltip_span, class: 'ml-1') if show_tooltip
      html
    end
  end

  def get_theme_taxonomy_ontologies
    params = {
      include: "themeTaxonomy",
      display_links: false,
      display_context: false,
      _ts: Time.current.to_i
    }
    result = LinkedData::Client::HTTP.get("#{LinkedData::Client.settings.rest_url}/", params).to_hash
    ontologies = []
    ontologies = result[:themeTaxonomy]&.filter { |u| u.strip.start_with?(rest_url) }.map { |u| u.strip.split('/').last }
    return ontologies
  end

  private
  
  def description_tooltip_help_text(label, description)
    title = content_tag(:span, "#{label}")
    render SummarySectionComponent.new(title: title, show_card: false) do
      # A bare String would be escaped on its way into the component, showing the
      # markup of the help text instead of rendering it.
      help_text = ActiveSupport::SafeBuffer.new
      unless description.nil? || description.empty?
        help_text += render(FieldContainerComponent.new(label: t('submission_inputs.help_text'), value: simple_format(description)))
      end

      help_text
    end
  end


  def attribute_metdata_help_text(attr)
    label = attr.label
    help = attr.helpText
    required = attr.required?
    attribute = !attr.namespace.nil? ? "#{attr.namespace}:#{attr.attribute}" : "bioportal:#{attr.attribute}"

    title = content_tag(:span, "#{label} (#{attribute})")
    title += content_tag(:span, 'required', class: 'badge badge-danger mx-1') if required

    render SummarySectionComponent.new(title: title, show_card: false) do
      help_text = ''
      unless attr.metadataMappings.nil?
        help_text += render(FieldContainerComponent.new(label: t('submission_inputs.equivalents'), value: attr.metadataMappings.join(', ')))
      end

      unless attr.enforce.nil? || attr.enforce.empty?
        help_text += render(FieldContainerComponent.new(label: t('submission_inputs.validators'), value: attr.enforce.map do |x|
          content_tag(:span, x.humanize, class: 'badge badge-primary mx-1')
        end.join.html_safe))
      end

      unless attr['helpText'].nil?
        help_text += render(FieldContainerComponent.new(label: t('submission_inputs.help_text'), value: help.html_safe))
      end

      help_text
    end
  end

end
