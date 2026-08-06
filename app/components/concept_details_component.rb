# frozen_string_literal: true

class ConceptDetailsComponent < ViewComponent::Base
  include ApplicationHelper
  include OntologiesHelper
  include MultiLanguagesHelper

  renders_one :header, TableComponent
  renders_many :sections, TableRowComponent

  attr_reader :concept_properties

  def initialize(id:, acronym:, concept_id: nil, properties: nil, top_keys: [], bottom_keys: [], exclude_keys: [])
    @acronym = acronym
    @properties = properties
    @top_keys = top_keys
    @bottom_keys = bottom_keys
    @exclude_keys = exclude_keys
    @id = id
    @concept_id = concept_id

    @concept_properties = concept_properties2hash(@properties) if @properties
  end

  def add_sections(keys, &block)
    scheme_set = properties_set_by_keys(keys, prefix_properties(concept_properties))
    rows = row_hash_properties(scheme_set, concept_properties, &block)

    rows.each do |row|
      section do |table_row|
        table_row.create(*row)
      end
    end

  end

  def row_hash_properties(properties_set, ontology_acronym, &block)
    out = []
    properties_set&.each do |key, data|
      next if exclude_relation?(key) || !data[:values]

      values = data[:values]
      url = data[:key]

      ajax_links = Array(values).map do |v|
        block_given? ? block.call(v) : row_value(v, ontology_acronym)
      end

      out << [
        { th: content_tag(:span, remove_owl_notation(key), title: url, 'data-controller': 'tooltip') },
        { td: list_items_component(max_items: 5) { |r| ajax_links.map { |val| r.container { val.html_safe } } } }
      ]
    end
    out
  end

  # One value of a row. In a single language it is a plain String; under "all
  # languages" it arrives as a [language, values] pair instead.
  #
  # Either shape can hold URIs, and those have to stay links: a reified node is
  # often language-specific (note_101800en, note_101800fr), so under "all
  # languages" it is a URI *inside* a language pair - which used to fall through
  # to the text rendering and come out unclickable.
  def row_value(value, ontology_acronym)
    return cls_ajax_link(value, ontology_acronym) if value.is_a?(String)

    language, values = value
    values = Array(values)
    return display_in_multiple_languages([value].to_h) unless values.any? && values.all? { |v| v.is_a?(String) && link?(v) }

    safe_join(values.map { |uri| linked_row_value(uri, ontology_acronym, language) })
  end

  # The link, tagged with the language it was read under - the tag the text
  # rendering would have shown.
  def linked_row_value(uri, ontology_acronym, language)
    link = cls_ajax_link(uri, ontology_acronym)
    return link if language.blank? || %w[NONE @NONE].include?(language.to_s.upcase)

    content_tag(:span, class: 'd-inline-flex align-items-center') do
      concat link
      concat content_tag(:span, language.to_s.upcase, class: 'badge badge-secondary ml-1')
    end
  end

  def cls_ajax_link(value, ontology_acronym)
    get_link_for_cls_ajax(value, ontology_acronym, '_blank', parent_id: @concept_id)
  end

  def properties_set_by_keys(keys, concept_properties, exclude_keys = [])
    concept_properties&.select do |k, v|
      (keys.include?(k) || !keys.select { |key| v[:key].to_s.include?(key) }.empty?) && !exclude_keys.include?(k) &&
        exclude_keys.select { |key| v[:key].to_s.include?(key) }.empty?
    end
  end

  def filter_properties(top_keys, bottom_keys, exclude_keys, concept_properties)
    all_keys = concept_properties&.keys || []
    top_set = properties_set_by_keys(top_keys, concept_properties, exclude_keys)
    bottom_set = properties_set_by_keys(bottom_keys, concept_properties, exclude_keys)
    leftover = properties_set_by_keys(all_keys, concept_properties, exclude_keys)
    leftover = leftover.reject { |key, _| top_set.key?(key) || bottom_set.key?(key) }
    [top_set, leftover, bottom_set]
  end

  private

  def link_to_format_modal(format, icon)
    link_to_modal(nil, "/ontologies/#{@acronym}/#{escape(@concept_id)}/serialize/#{format}", { id: "resource_content_#{format}", data: { show_modal_title_value: @concept_id, show_modal_size_value: 'modal-xl' } }) do
      inline_svg("icons/#{icon}.svg", width: '50px', height: '50px')
    end
  end

  def concept_properties2hash(properties)
    # NOTE: example properties
    #
    # properties
    #=> #<struct
    #  http://www.w3.org/2000/01/rdf-schema#label=
    #    [#<struct
    #      object="Etiological thing",
    #      string="Etiological thing",
    #      links=nil,
    #      context=nil>],
    #  http://stagedata.bioontology.org/metadata/def/prefLabel=
    #    [#<struct
    #      object="Etiological thing",
    #      string="Etiological thing",
    #      datatype="http://www.w3.org/2001/XMLSchema#string",
    #      links=nil,
    #      context=nil>],
    #  http://www.w3.org/2000/01/rdf-schema#comment=
    #    [#<struct  object="AD444", string="AD444", links=nil, context=nil>],
    #  http://scai.fraunhofer.de/NDDUO#Synonym=
    #    [#<struct  object="Etiology", string="Etiology", links=nil, context=nil>],
    #  http://www.w3.org/2000/01/rdf-schema#subClassOf=
    #    ["http://www.w3.org/2002/07/owl#Thing"],
    #  http://www.w3.org/1999/02/22-rdf-syntax-ns#type=
    #    ["http://www.w3.org/2002/07/owl#Class"],
    #  links=nil,
    #  context=nil>
    properties_data = {}
    keys = properties.members # keys is an array of symbols
    keys.each do |key|
      next if properties[key].nil? # ignore :context and :links when nil.

      # Shorten the key into a simple label
      k = key.to_s if key.kind_of?(Symbol)
      k ||= key
      label = key
      if k.start_with?("http")
        label = LinkedData::Client::HTTP.get("/ontologies/#{@ontology.acronym}/properties/#{CGI.escape(k)}/label").label rescue ""
        if label.nil? || label.empty?
          k = k.gsub(/.*#/, '') # greedy regex replace everything up to last '#'
          k = k.gsub(/.*\//, '') # greedy regex replace everything up to last '/'
          # That might take care of nearly everything to be shortened.
          label = k
        end
      end
      begin
        # Try to simplify the property values, when they are a struct.
        if properties[key].is_a?(OpenStruct)
          values = language_hash(properties[key])
        else
          values = properties[key].map { |v| v.string }
        end
      rescue
        # Each value is probably a simple datatype already.
        values = properties[key]
      end
      data = { :key => key, :values => values }
      properties_data[label] = data
    end
    return properties_data
  end

  def exclude_relation?(relation_to_check, ontology = nil)
    excluded_relations = ["type", "rdf:type", "[R]", "SuperClass", "InstanceCount"]

    # Show or hide property based on the property and ontology settings
    if ontology
      # TODO_REV: Handle obsolete classes
      # Hide owl:deprecated if a user has set class or property based obsolete checking
      # if !ontology.obsoleteParent.nil? && relation_to_check.include?("owl:deprecated") || !ontology.obsoleteProperty.nil? && relation_to_check.include?("owl:deprecated")
      #   return true
      # end
    end

    excluded_relations.each do |relation|
      return true if relation_to_check.is_a?(Array) && relation_to_check.include?(relation)
    end
    return false
  end

  def remove_owl_notation(string)
    # TODO_REV: No OWL notation, but should we modify the IRI?
    return string

    unless string.nil?
      strings = string.split(":")
      if strings.size < 2
        # return string.titleize
        return string
      else
        # return strings[1].titleize
        return strings[1]
      end
    end
  end

  def convert_dates(hash)
    hash.transform_values do |property|
      if property[:key].to_s.include?("http://purl.org/dc/terms/created") || property[:key].to_s.include?("http://purl.org/dc/terms/modified")
        value = property[:values].first
        parsed_date = l(Date.parse(value), format: :monthfull_day_year.to_sym) rescue value
        property[:values] = [parsed_date]
      end
      property
    end
  end

end
