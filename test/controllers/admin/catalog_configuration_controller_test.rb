# frozen_string_literal: true

require 'test_helper'
require_relative '../../helpers/application_test_helpers'

# Unit tests for the federation-eligibility gating of the catalog configuration
# form. The current portal is identified by the request host (not a configurable
# setting), then matched against the federated portals published on
# ontoportal.org.
class Admin::CatalogConfigurationControllerTest < ActiveSupport::TestCase
  include ApplicationTestHelpers::Federation

  # Build a controller whose request host and federation list are fixed, so the
  # pure gating methods can be exercised without dispatching a real request.
  def build_controller(host:, instances:)
    controller = Admin::CatalogConfigurationController.new
    controller.define_singleton_method(:request) { OpenStruct.new(host: host) }
    controller.define_singleton_method(:federated_ontoportal_instances) { instances }
    controller
  end

  def with_rails_env(env)
    original = Rails.env
    Rails.env = env
    yield
  ensure
    Rails.env = original
  end

  test 'derives the current portal domain from the request host' do
    controller = build_controller(host: 'agroportal.eu', instances: [AGROPORTAL])
    assert_equal 'agroportal.eu', controller.send(:current_portal_domain)
  end

  test 'allows federation when the request host matches a federated portal' do
    controller = build_controller(host: 'agroportal.eu', instances: [AGROPORTAL])
    assert controller.send(:current_portal_federated_on_source?)
  end

  test 'forbids federation when the request host is not a federated portal' do
    controller = build_controller(host: 'unknown.example.org', instances: [AGROPORTAL])
    assert_not controller.send(:current_portal_federated_on_source?)
  end

  test 'gates the form on the request host outside development' do
    controller = build_controller(host: 'unknown.example.org', instances: [AGROPORTAL])
    assert_not controller.send(:federation_allowed?)

    controller = build_controller(host: 'agroportal.eu', instances: [AGROPORTAL])
    assert controller.send(:federation_allowed?)
  end

  test 'does not gate the form in development' do
    controller = build_controller(host: 'unknown.example.org', instances: [AGROPORTAL])

    with_rails_env('development') do
      assert controller.send(:federation_allowed?)
    end
  end

  test 'excludes the current portal from the federated list' do
    controller = build_controller(host: 'agroportal.eu', instances: [AGROPORTAL])
    domain = controller.send(:current_portal_domain)

    portals = [
      OpenStruct.new(ui: 'https://agroportal.eu/', api: 'https://data.agroportal.eu/'),
      OpenStruct.new(ui: 'https://other.portal.org/', api: 'https://data.other.portal.org/')
    ]

    result = controller.send(:reject_current_portal, portals, domain)
    assert_equal ['https://other.portal.org/'], result.map(&:ui)
  end

  # Federated portals moved out of the site description form to the site
  # administration section, but they are still part of the catalog config the
  # controller reads and writes.
  test 'keeps federated portals out of the site description groups' do
    controller = Admin::CatalogConfigurationController.new
    groups = controller.send(:attributes_groups)

    assert_not_includes groups.values.flatten, 'federated_portals'
    assert_includes controller.send(:list_included_attributes), 'federated_portals'
  end

  test 'recognizes a federated portals submission' do
    controller = Admin::CatalogConfigurationController.new
    controller.params = ActionController::Parameters.new(
      config: { 'federated_portals' => [{ 'name' => 'Other', 'apikey' => '' }] }
    )

    assert controller.send(:federated_portals_update?)
  end

  test 'does not take a site description submission for a federated portals one' do
    controller = Admin::CatalogConfigurationController.new
    controller.params = ActionController::Parameters.new(config: { 'title' => 'AgroPortal' })

    assert_not controller.send(:federated_portals_update?)
  end
end
