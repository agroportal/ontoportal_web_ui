# frozen_string_literal: true

require 'test_helper'

# The Danger Zone of the ontology admin page, as an ontology admin sees it:
# no admin session, so no deletion (agroportal/project-management#765)
class OntologyAdminDangerZoneTest < ActionView::TestCase
  VISIBILITY_FORM = "form[action='/ontologies/STY/administration/visibility']"

  test 'offers to make a public ontology private' do
    @ontology = OpenStruct.new(acronym: 'STY', viewingRestriction: 'public')

    render partial: 'ontologies/admin/danger_zone'

    assert_select '.danger-zone-item p', text: 'This ontology is currently public.'
    assert_select "#{VISIBILITY_FORM} input[name=visibility][value=private]"
    assert_select "#{VISIBILITY_FORM} button[data-confirm]", text: 'Change to private'
  end

  test 'offers to make a private ontology public' do
    @ontology = OpenStruct.new(acronym: 'STY', viewingRestriction: 'private')

    render partial: 'ontologies/admin/danger_zone'

    assert_select "#{VISIBILITY_FORM} input[name=visibility][value=public]"
    assert_select "#{VISIBILITY_FORM} button", text: 'Change to public'
  end

  test 'leaves the deletion to portal admins' do
    @ontology = OpenStruct.new(acronym: 'STY', viewingRestriction: 'public')

    render partial: 'ontologies/admin/danger_zone'

    assert_select '.danger-zone-item', count: 1
    assert_select "a[href='/ontologies/STY/administration/delete']", count: 0
  end
end
