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
  DELETE_ZONE = '.ontology-delete-zone'
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
    assert_select DELETE_ZONE

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
    assert_select DELETE_ZONE, count: 0

    delete owned_page, params: { confirmation: OWNED[:acronym] }
    assert_redirected_to '/'
    assert ontology_exists?
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

  # The API answers a missing ontology with an error object, not nil
  def ontology_exists?
    ontology = LinkedData::Client::Models::Ontology.find_by_acronym(OWNED[:acronym], invalidate_cache: true).first
    ontology&.acronym == OWNED[:acronym]
  end
end
