# frozen_string_literal: true

require 'test_helper'

class FederationHelperTest < ActionView::TestCase
  include FederationHelper

  BIOPORTAL = {
    name: 'BioPortal',
    ui: 'https://bioportal.bioontology.org/',
    api: 'https://data.bioontology.org/',
    apikey: '11111111-2222-3333-4444-555555555555'
  }.freeze

  ECOPORTAL = {
    name: 'EcoPortal',
    ui: 'https://ecoportal.lifewatch.eu/',
    api: 'https://data.ecoportal.lifewatch.eu/',
    apikey: '66666666-7777-8888-9999-000000000000'
  }.freeze

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    FederatedPortal.delete_all
  end

  teardown do
    Rails.cache = @original_cache
  end

  def catalog_answers(portals = nil)
    define_singleton_method(:fetch_federated_portals_from_catalog) do |**|
      flunk('the catalog should not have been read') if portals.nil?
      portals
    end
  end

  def signed_in_as_admin(admin)
    user = Object.new
    user.define_singleton_method(:admin?) { admin }
    session[:user] = user
  end

  test 'serves the cached configuration' do
    Rails.cache.write(FederatedPortal::CACHE_KEY, { bioportal: BIOPORTAL })
    catalog_answers

    assert_equal({ bioportal: BIOPORTAL }, federated_portals)
  end

  test 'falls back to the database when the cache is cold' do
    FederatedPortal.sync!(bioportal: BIOPORTAL)
    catalog_answers

    assert_equal({ bioportal: BIOPORTAL }, federated_portals)
  end

  test 'warms the cache from the database' do
    FederatedPortal.sync!(bioportal: BIOPORTAL)
    catalog_answers
    federated_portals

    assert_equal({ bioportal: BIOPORTAL }, Rails.cache.read(FederatedPortal::CACHE_KEY))
  end

  test 'stores the catalog answer for an administrator' do
    signed_in_as_admin(true)
    catalog_answers(bioportal: BIOPORTAL, ecoportal: ECOPORTAL)

    assert_equal %i[bioportal ecoportal], federated_portals.keys
    assert_equal %i[bioportal ecoportal], FederatedPortal.as_config.keys
    assert_equal %i[bioportal ecoportal], Rails.cache.read(FederatedPortal::CACHE_KEY).keys
  end

  test 'does not store the catalog answer of a plain visitor' do
    signed_in_as_admin(false)
    catalog_answers(bioportal: BIOPORTAL)
    federated_portals

    assert_empty FederatedPortal.as_config
    assert_nil Rails.cache.read(FederatedPortal::CACHE_KEY)
  end

  test 'reports no federation when nothing is cached, stored or published' do
    signed_in_as_admin(true)
    catalog_answers({})

    assert_empty federated_portals
    assert_not federation_enabled?
  end
end
