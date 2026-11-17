# frozen_string_literal: true

require 'test_helper'

# The object description properties section of the ontology admin page,
# moved from the edit page
class OntologyAdminObjectDescriptionTest < ActionView::TestCase
  FORM = "turbo-frame#object_description form[action='/ontologies/STY/administration/object_description']"

  setup do
    @ontology = OpenStruct.new(acronym: 'STY')
    @attributes = %w[prefLabelProperty synonymProperty]
  end

  test 'edits the properties of the latest submission' do
    @submission_id = 2

    render partial: 'ontologies/admin/object_description'

    assert_select "#{FORM} input[name=_method][value=patch]"
    assert_select "#{FORM} input[name=submission_id][value='2']"
    # The inputs of the edit page, for the properties of the section only
    inputs = css_select("#{FORM} turbo-frame#object_description_inputs").first
    assert_equal '/ontologies/STY/submissions/2/edit_properties?container_id=object_description_inputs&properties=prefLabelProperty%2CsynonymProperty',
                 inputs['src']
  end

  test 'says when the ontology has no submission yet' do
    @submission_id = nil

    render partial: 'ontologies/admin/object_description'

    assert_select 'turbo-frame#object_description p', text: 'STY has no submission yet.'
    assert_select 'form', count: 0
  end
end
