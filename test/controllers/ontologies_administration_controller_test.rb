# frozen_string_literal: true

require 'test_helper'
require_relative '../helpers/application_test_helpers'

# Admins reach the ontology administration page from the gear button of the
# ontology header. Only portal admins may delete the ontology from it.
class OntologiesAdministrationControllerTest < ActionDispatch::IntegrationTest
  include ApplicationTestHelpers::Users
  include ApplicationTestHelpers::Ontologies

  ACRONYM = 'STY'
  PAGE = "/ontologies/#{ACRONYM}/administration"
  GEAR_BUTTON = "a.rounded-button[href='#{PAGE}']"
  DANGER_ZONE = '.danger-zone'
  DELETE_BUTTON = "a[href$='/administration/delete']"
  HTML = { 'Accept' => 'text/html' }.freeze
  # Seeded by bin/run_api
  PORTAL_ADMIN = { username: 'admin', password: 'password' }.freeze
  # Administered by a regular user, deleted by the tests
  OWNED = { acronym: 'ADMINDEL', name: 'Ontology deleted from its admin page' }.freeze

  teardown do
    delete_ontologies([@owned]) if @owned
    delete_user(@owner) if @owner
  end

  test 'admins open the page and its frames from the gear button' do
    post login_index_url, params: { user: PORTAL_ADMIN }

    get "/ontologies/#{ACRONYM}", headers: HTML
    assert_select GEAR_BUTTON

    # The frames load lazily in the browser: request them as it would
    [PAGE, "#{PAGE}/submissions", "#{PAGE}/log"].each do |path|
      get path
      assert_response :success, "GET #{path} returned #{response.status}"
    end
  end

  test 'admins download the log of the latest submission' do
    post login_index_url, params: { user: PORTAL_ADMIN }

    get "#{PAGE}/log.txt"
    assert_response :success
    assert_equal 'text/plain', response.media_type
    assert_includes response.headers['Content-Disposition'], %(attachment; filename="#{ACRONYM}-latest-submission-log.txt")
  end

  test 'the state of a submission opens its processing details' do
    post login_index_url, params: { user: PORTAL_ADMIN }

    get "#{PAGE}/submissions"
    details = css_select('a.submission-state').first['href']

    get details
    assert_response :success
    assert_select 'turbo-frame#application_modal_content .submission-processing'
  end

  test 'visitors get neither the gear button nor the page' do
    get "/ontologies/#{ACRONYM}", headers: HTML
    assert_select GEAR_BUTTON, count: 0

    get PAGE
    assert_redirected_to '/'
  end

  test 'portal admins delete the ontology once they type its acronym' do
    create_owned_ontology
    post login_index_url, params: { user: PORTAL_ADMIN }

    get owned_page
    assert_select "#{DANGER_ZONE} #{DELETE_BUTTON}"

    # The confirmation the Danger Zone opens in the application modal
    get "#{owned_page}/delete"
    assert_select "turbo-frame#application_modal_content form[action='#{owned_page}'] input[name=confirmation]"

    delete owned_page, params: { confirmation: OWNED[:acronym].downcase }
    assert_redirected_to owned_page
    assert ontology_exists?

    delete owned_page, params: { confirmation: OWNED[:acronym] }
    assert_redirected_to my_ontologies_path
    assert_not ontology_exists?
  end

  # agroportal/project-management#765
  test 'ontology admins may not delete their ontology' do
    create_owned_ontology
    post login_index_url, params: { user: { username: @owner.username, password: @owner.password } }

    get owned_page
    assert_response :success
    assert_select DANGER_ZONE
    assert_select DELETE_BUTTON, count: 0

    get "#{owned_page}/delete"
    assert_redirected_to '/'

    delete owned_page, params: { confirmation: OWNED[:acronym] }
    assert_redirected_to '/'
    assert ontology_exists?
  end

  # As on the edit page, which already lets them
  test 'ontology admins change the visibility of their ontology' do
    create_owned_ontology
    post login_index_url, params: { user: { username: @owner.username, password: @owner.password } }

    patch "#{owned_page}/visibility", params: { visibility: 'hidden' }
    assert_response :bad_request

    %w[private public].each do |visibility|
      patch "#{owned_page}/visibility", params: { visibility: visibility }
      assert_redirected_to owned_page
      assert_equal visibility, owned_ontology.viewingRestriction
    end
  end

  test 'ontology admins choose the accounts allowed to see their ontology' do
    create_owned_ontology
    post login_index_url, params: { user: { username: @owner.username, password: @owner.password } }

    get "#{owned_page}/accounts"
    assert_select "turbo-frame#application_modal_content form[action='#{owned_page}/accounts'] select[name='acl[]']"

    owner_id = LinkedData::Client::Models::User.find_by_username(@owner.username).first.id
    patch "#{owned_page}/accounts", params: { acl: [owner_id] }
    assert_redirected_to owned_page
    assert_equal [owner_id], owned_ontology_acl

    # Without any account selected, the form sends no acl
    patch "#{owned_page}/accounts"
    assert_redirected_to owned_page
    assert_empty owned_ontology_acl
  end

  private

  def create_owned_ontology
    @owner = create_user(fixtures(:users)[:john])
    # Left over by an aborted run
    delete_ontologies([OpenStruct.new(OWNED)])
    @owned = LinkedData::Client::Models::Ontology.new(values: OWNED.merge(administeredBy: [@owner.username])).save
    assert_nil @owned.errors, "Could not create #{OWNED[:acronym]}"
  end

  def owned_page
    "/ontologies/#{OWNED[:acronym]}/administration"
  end

  def owned_ontology
    LinkedData::Client::Models::Ontology.find_by_acronym(OWNED[:acronym], invalidate_cache: true).first
  end

  # Not among the attributes the API returns by default
  def owned_ontology_acl
    Array(LinkedData::Client::HTTP.get("/ontologies/#{OWNED[:acronym]}", include: 'acl', invalidate_cache: true).acl)
  end

  # The API answers a missing ontology with an error object, not nil
  def ontology_exists?
    owned_ontology&.acronym == OWNED[:acronym]
  end
end
