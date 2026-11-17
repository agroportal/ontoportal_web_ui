# frozen_string_literal: true

require 'test_helper'

# The Danger Zone of the ontology admin page, as an ontology admin sees it:
# no admin session, so no deletion (agroportal/project-management#765)
class OntologyAdminDangerZoneTest < ActionView::TestCase
  VISIBILITY_FORM = "form[action='/ontologies/STY/administration/visibility']"
  ACCOUNTS_LINK = "a.dropdown-item[href='/ontologies/STY/administration/accounts']"
  # As the API lists them: user URIs
  USERS = %w[http://data.example.org/users/alice http://data.example.org/users/bob].freeze

  test 'offers to make a public ontology private' do
    @ontology = OpenStruct.new(acronym: 'STY', viewingRestriction: 'public')

    render partial: 'ontologies/admin/danger_zone'

    assert_select '.danger-zone-item p', text: 'This ontology is currently public.'
    assert_select "#{VISIBILITY_FORM} input[name=visibility][value=private]"
    assert_select "#{VISIBILITY_FORM} button[data-confirm]", text: 'Change to private'
    # Its access list applies once private
    assert_select ACCOUNTS_LINK, count: 0
  end

  test 'offers to make a private ontology public' do
    @ontology = OpenStruct.new(acronym: 'STY', viewingRestriction: 'private')

    render partial: 'ontologies/admin/danger_zone'

    assert_select "#{VISIBILITY_FORM} input[name=visibility][value=public]"
    assert_select "#{VISIBILITY_FORM} button", text: 'Change to public'
  end

  test 'lists and edits the accounts allowed to see a private ontology' do
    @ontology = OpenStruct.new(acronym: 'STY', viewingRestriction: 'private')
    @acl = USERS

    render partial: 'ontologies/admin/danger_zone'

    assert_select '.danger-zone-item p', text: 'Accounts allowed: alice and bob.'
    assert_select ACCOUNTS_LINK, text: 'Choose who can see this ontology'
  end

  test 'says when no account is allowed besides the administrators' do
    @ontology = OpenStruct.new(acronym: 'STY', viewingRestriction: 'private')
    @acl = []

    render partial: 'ontologies/admin/danger_zone'

    assert_select '.danger-zone-item p', text: 'No account is allowed besides its administrators.'
  end

  test 'leaves the deletion to portal admins' do
    @ontology = OpenStruct.new(acronym: 'STY', viewingRestriction: 'public')

    render partial: 'ontologies/admin/danger_zone'

    assert_select '.danger-zone-item', count: 1
    assert_select "a[href='/ontologies/STY/administration/delete']", count: 0
  end
end
