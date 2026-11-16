# frozen_string_literal: true

require 'test_helper'

# Admins reach the ontology administration page from the gear button of the
# ontology header. The page has no route to delete the ontology.
class OntologiesAdministrationControllerTest < ActionDispatch::IntegrationTest
  ACRONYM = 'STY'
  PAGE = "/ontologies/#{ACRONYM}/administration"
  GEAR_BUTTON = "a.rounded-button[href='#{PAGE}']"
  HTML = { 'Accept' => 'text/html' }.freeze
  # Seeded by bin/run_api
  PORTAL_ADMIN = { username: 'admin', password: 'password' }.freeze

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

  test 'visitors get neither the gear button nor the page' do
    get "/ontologies/#{ACRONYM}", headers: HTML
    assert_select GEAR_BUTTON, count: 0

    get PAGE
    assert_redirected_to '/'
  end

  test 'the page cannot delete the ontology' do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(PAGE, method: :delete)
    end
  end
end
