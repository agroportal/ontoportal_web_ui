# frozen_string_literal: true

class OntologyBrowseCardComponent < ViewComponent::Base
  include ApplicationHelper, OntologiesHelper, FederationHelper, ComponentsHelper

  def initialize(ontology: nil, onto_link: nil, text_color: nil, bg_light_color: nil, portal_name: nil)
    super()
    @ontology = ontology
    @text_color = text_color
    @bg_light_color =  bg_light_color
    @onto_link = onto_link || "/ontologies/#{@ontology[:acronym]}" if @ontology
    @portal_name = portal_name
  end

  def ontology
    @ontology
  end

  def external_ontology?
    !internal_ontology?(@ontology[:id])
  end

  def onto_link
    @onto_link
  end

  def style_text
    external_ontology? ? "color: #{@text_color} !important" : ''
  end

  def portal_color
    @text_color
  end
  alias :color :portal_color

  def style_bg
    external_ontology? ?  "#{style_text} ; background-color: #{@bg_light_color}" : ''
  end

end
