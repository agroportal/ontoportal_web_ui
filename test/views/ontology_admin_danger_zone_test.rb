# frozen_string_literal: true

require 'test_helper'

# The Danger Zone of the ontology admin page, as an ontology admin sees it:
# no admin session, so no deletion (agroportal/project-management#765)
class OntologyAdminDangerZoneTest < ActionView::TestCase
  VISIBILITY_FORM = "form[action='/ontologies/STY/administration/visibility']"
  # As the API lists them: user URIs
  USERS = %w[http://data.example.org/users/alice http://data.example.org/users/bob].freeze

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

  # Administrators grant access now: the menu only switches the visibility
  test 'lists the accounts allowed to see a private ontology' do
    @ontology = OpenStruct.new(acronym: 'STY', viewingRestriction: 'private')
    @acl = USERS

    render partial: 'ontologies/admin/danger_zone'

    assert_select '.danger-zone-item p', text: 'Accounts allowed: alice and bob.'
    assert_select '.dropdown-menu .dropdown-item', count: 1
  end

  test 'says when no account is allowed besides the administrators' do
    @ontology = OpenStruct.new(acronym: 'STY', viewingRestriction: 'private')
    @acl = []

    render partial: 'ontologies/admin/danger_zone'

    assert_select '.danger-zone-item p', text: 'No account is allowed besides its administrators.'
  end

  test 'manages the administrators' do
    @ontology = OpenStruct.new(acronym: 'STY', viewingRestriction: 'public', administeredBy: USERS)

    render partial: 'ontologies/admin/danger_zone'

    assert_select '.danger-zone-item p', text: 'Administrators can see and modify its metadata, even when it is private.'
    # The modal lists them
    assert_not_includes rendered, 'alice'
    assert_select "a.btn-outline-danger[href='/ontologies/STY/administration/administrators']", text: 'Manage administrators'
  end

  test 'leaves the deletion to portal admins' do
    @ontology = OpenStruct.new(acronym: 'STY', viewingRestriction: 'public')

    render partial: 'ontologies/admin/danger_zone'

    # Visibility and administrators
    assert_select '.danger-zone-item', count: 2
    assert_select "a[href='/ontologies/STY/administration/delete']", count: 0
  end
end
