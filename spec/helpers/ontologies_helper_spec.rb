# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OntologiesHelper, type: :helper do
  let(:node) { 'http://aims.fao.org/aos/agrovoc/xDef_46a719b8' }

  API_BUTTON = 'concepts_json_button'

  def details_for(object)
    helper.ontology_object_details_component(frame_id: 'instance_show', ontology_id: 'AGROVOC',
                                             objects_title: 'instances', object: object) { 'Details' }
  end

  describe '#ontology_object_details_component' do
    it 'offers the API view of a resource the API answered with' do
      expect(details_for(OpenStruct.new('@id' => node))).to include(API_BUTTON)
    end

    it 'offers none for a node only SPARQL could resolve' do
      expect(details_for(ResourceLookupService::Resource.build(node, {}))).not_to include(API_BUTTON)
    end
  end
end
