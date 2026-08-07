# frozen_string_literal: true

require 'test_helper'
require_relative '../../helpers/application_test_helpers'

# Unit tests for the federation-eligibility gating of the catalog configuration
# form. The current portal is identified by the request host (not a configurable
# setting), then matched against the federated portals published on
# ontoportal.org.
class Admin::CatalogConfigurationControllerTest < ActiveSupport::TestCase
  include ApplicationTestHelpers::Federation

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    FederatedPortal.delete_all
  end

  teardown do
    Rails.cache = @original_cache
  end

  # Build a controller whose request host and federation list are fixed, so the
  # pure gating methods can be exercised without dispatching a real request.
  def build_controller(host:, instances:)
    controller = Admin::CatalogConfigurationController.new
    controller.define_singleton_method(:request) { OpenStruct.new(host: host) }
    controller.define_singleton_method(:federated_ontoportal_instances) { instances }
    controller
  end

  def build_controller_reading(portals)
    recorded = @catalog_read_options = {}
    view = Object.new.extend(FederationHelper)
    view.define_singleton_method(:fetch_federated_portals_from_catalog) do |**options|
      recorded.merge!(options)
      portals
    end

    controller = Admin::CatalogConfigurationController.new
    controller.define_singleton_method(:helpers) { view }
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

  test 'stores a saved federation in both the cache and the database' do
    controller = build_controller_reading(agroportal: AGROPORTAL)

    controller.send(:refresh_federated_portals)

    assert_equal({ agroportal: AGROPORTAL }, Rails.cache.read(FederatedPortal::CACHE_KEY))
    assert_equal({ agroportal: AGROPORTAL }, FederatedPortal.as_config)
  end

  test 'clears both copies when the federation is emptied' do
    FederatedPortal.sync!(agroportal: AGROPORTAL)
    Rails.cache.write(FederatedPortal::CACHE_KEY, { agroportal: AGROPORTAL })

    build_controller_reading({}).send(:refresh_federated_portals)

    assert_nil Rails.cache.read(FederatedPortal::CACHE_KEY)
    assert_empty FederatedPortal.as_config
  end

  test 'reads the catalog back past its http cache after a save' do
    build_controller_reading(agroportal: AGROPORTAL).send(:refresh_federated_portals)

    assert @catalog_read_options[:bust_cache]
  end

  test 'gives the cached copy an expiry so it cannot outlive a bad write' do
    build_controller_reading(agroportal: AGROPORTAL).send(:refresh_federated_portals)
    assert_not_nil Rails.cache.read(FederatedPortal::CACHE_KEY)

    travel FederatedPortal::CACHE_TTL + 1.minute do
      assert_nil Rails.cache.read(FederatedPortal::CACHE_KEY)
    end
  end
end
