# frozen_string_literal: true

require 'test_helper'
require_relative '../helpers/application_test_helpers'

# Admins reach the ontology administration page from the gear button of the
# ontology header.
class OntologiesAdministrationControllerTest < ActionDispatch::IntegrationTest
  include ApplicationTestHelpers::Users
  include ApplicationTestHelpers::Ontologies

  ACRONYM = 'STY'
  PAGE = "/ontologies/#{ACRONYM}/administration"
  GEAR_BUTTON = "a.rounded-button[href='#{PAGE}']"
  HTML = { 'Accept' => 'text/html' }.freeze
  # Seeded by bin/run_api
  PORTAL_ADMIN = { username: 'admin', password: 'password' }.freeze
  # Administered by a regular user, deleted by the tests
  OWNED = { acronym: 'ADMINDEL', name: 'Ontology administered by a regular user' }.freeze

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

  # Moved from the edit page
  test 'the object description properties have their own section' do
    post login_index_url, params: { user: PORTAL_ADMIN }

    get "#{PAGE}/object_description"
    assert_response :success
    assert_select "turbo-frame#object_description form[action='#{PAGE}/object_description'] input[name=submission_id]"
    assert_select "turbo-frame#object_description_inputs[src*='properties=']"
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

  test 'ontology admins manage the administrators of their ontology' do
    create_owned_ontology
    post login_index_url, params: { user: { username: @owner.username, password: @owner.password } }
    owner_id, admin_id = [@owner.username, PORTAL_ADMIN[:username]].map do |username|
      LinkedData::Client::Models::User.find_by_username(username).first.id
    end

    # Every account, the current administrators selected
    get "#{owned_page}/administrators"
    assert_select "turbo-frame#application_modal_content select[name='administrators[]'] option[value='#{owner_id}'][selected]"
    assert_select "option[value='#{admin_id}']:not([selected])"

    patch "#{owned_page}/administrators", params: { administrators: [owner_id, admin_id] }
    assert_redirected_to owned_page
    assert_equal [admin_id, owner_id].sort, Array(owned_ontology.administeredBy).sort

    # The API requires one administrator at least
    patch "#{owned_page}/administrators"
    assert_redirected_to owned_page
    assert_equal 2, Array(owned_ontology.administeredBy).size

    # Who removes themselves can no longer open the admin page
    patch "#{owned_page}/administrators", params: { administrators: [admin_id] }
    assert_redirected_to "/ontologies/#{OWNED[:acronym]}"
    assert_equal [admin_id], Array(owned_ontology.administeredBy)
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
end
