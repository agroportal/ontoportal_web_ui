class Display::SearchResultComponent < ViewComponent::Base
  include UrlsHelper
  include ModalHelper
  include MultiLanguagesHelper
  include FederationHelper
  include ComponentsHelper

  renders_many :subresults, Display::SearchResultComponent
  renders_many :reuses, Display::SearchResultComponent

  def initialize(number: 0,title: nil, ontology_id: nil ,uri: nil, definition: nil, link: nil, lang: 'all',  is_sub_component: false, portal_name: nil, portal_color: nil, portal_light_color: nil, other_portals: [])
      @title = title
      @uri = uri
      @definition = definition
      @lang = lang
      @link = link
      @is_sub_component = is_sub_component
      @ontology_acronym = ontology_id&.split('/')&.last
      @number = number.to_s
      @portal_name = portal_name
      @portal_color = portal_color
      @portal_light_color = portal_light_color
      @other_portals = other_portals
  end

  # A result reads its definitions the way the concept page does - a reified
  # node is never set as prose - but reads them as a summary: the node's own
  # data is already a click away behind Details, so a node the row can already
  # read costs no lookup here. A class from another portal is looked up nowhere,
  # our API knowing nothing of it.
  def definitions_component
    DefinitionsComponent.new(definitions: @definition, lang: @lang, parent_uri: @uri,
                             acronym: external_class? ? nil : @ontology_acronym,
                             lookup: DefinitionsComponent::LOOKUP_SUMMARY)
  end

  def sub_component_class
      @is_sub_component ? 'sub-component' : ''
  end

  def sub_ontologies_id
    string = @number+'_sub_ontologies'
  end

  def reuses_id
    string = @number+'_reuses'
  end

  def details_button
      link_to_modal(nil, "/ajax/class_details?modal=true&ontology=#{@ontology_acronym}&conceptid=#{@uri}&styled=false", data: { show_modal_title_value: @title, show_modal_size_value: 'modal-xl' }) do
        content_tag(:div, class: 'button') do
          concat inline_svg_tag('icons/details.svg')
          concat content_tag(:div, class: 'text') { t('search.result_component.details') }
        end
      end
  end

  def mappings_button
    link_to_modal(nil, "/ajax/mappings/get_concept_table?ontologyid=#{@ontology_acronym}&conceptid=#{escape(@uri)}&type=modal", data: { show_modal_title_value: @title, show_modal_size_value: 'modal-xl' }) do
      content_tag(:div, class: 'button') do
        inline_svg_tag('icons/ontology.svg') +
        content_tag(:div, class: 'text d-flex') do
          render(TurboFrameComponent.new(id: 'mapping_count', src: "/ajax/mappings/get_concept_table?ontologyid=#{@ontology_acronym}&conceptid=#{escape(@uri)}", loading: "lazy")) do |t|
            t.loader do
             render LoaderComponent.new(small: true)
            end
            t.error do
              "-1"
            end
          end + content_tag(:div, 'mappings', class: 'ml-1')
        end
      end
    end
  end

  def visualize_button
      link_to_modal(nil, "/ajax/biomixer/?ontology=#{@ontology_acronym}&conceptid=#{@uri}", data: { show_modal_title_value: @title, show_modal_size_value: 'modal-xl' }) do
        content_tag(:div, class: 'button') do
          concat inline_svg_tag('icons/visualize.svg')
          concat content_tag(:div, class: 'text') { t('search.result_component.visualize') }
        end
      end
  end

  def reveal_ontologies_button(text,id,icon)
    content_tag(:div, class: 'button icon-right', 'data-action': "click->reveal-component#toggle", 'data-id': id, style: @portal_color ? "background-color: #{@portal_light_color} !important" : '') do
      inline_svg_tag(icon, class: "federated-icon-#{@portal_name}") +
      content_tag(:div, class: 'text', style: @portal_color ? "color: #{@portal_color} !important" : '') do
        text
      end +
      inline_svg_tag("icons/arrow-down.svg", class: "federated-icon-#{@portal_name}")
    end
  end

  def external_class?
    !@portal_name.nil?
  end

  def all_federated_portals
    out = Array(@other_portals)
    out.prepend({name: @portal_name, color: @portal_color, light_color: @portal_light_color, link: @link}) if external_class?
    out
  end
end
