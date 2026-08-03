# frozen_string_literal: true

require 'test_helper'

class FederatedPortalTest < ActiveSupport::TestCase
  BIOPORTAL = {
    name: 'BioPortal',
    ui: 'https://bioportal.bioontology.org/',
    api: 'https://data.bioontology.org/',
    color: '#234567',
    apikey: '11111111-2222-3333-4444-555555555555'
  }.freeze

  ECOPORTAL = {
    name: 'EcoPortal',
    ui: 'https://ecoportal.lifewatch.eu/',
    api: 'https://data.ecoportal.lifewatch.eu/',
    color: '#abcdef',
    apikey: '66666666-7777-8888-9999-000000000000',
    'light-color': '#fedcba'
  }.freeze

  setup do
    FederatedPortal.delete_all
  end

  test 'reads back the configuration it was given' do
    FederatedPortal.sync!(bioportal: BIOPORTAL, ecoportal: ECOPORTAL)

    assert_equal({ bioportal: BIOPORTAL, ecoportal: ECOPORTAL }, FederatedPortal.as_config)
  end

  test 'accepts the openstructs the catalog answers with' do
    FederatedPortal.sync!(bioportal: OpenStruct.new(BIOPORTAL))

    assert_equal({ bioportal: BIOPORTAL }, FederatedPortal.as_config)
  end

  test 'keeps the apikeys out of the clear' do
    FederatedPortal.sync!(bioportal: BIOPORTAL)
    stored = FederatedPortal.sole

    assert_not_equal BIOPORTAL[:apikey], stored.encrypted_apikey
    assert_not_includes stored.encrypted_apikey, BIOPORTAL[:apikey]
    assert_equal BIOPORTAL[:apikey], stored.apikey
  end

  test 'drops the portals the catalog no longer lists' do
    FederatedPortal.sync!(bioportal: BIOPORTAL, ecoportal: ECOPORTAL)
    FederatedPortal.sync!(bioportal: BIOPORTAL)

    assert_equal [:bioportal], FederatedPortal.as_config.keys
  end

  test 'clears every portal when the federation is emptied' do
    FederatedPortal.sync!(bioportal: BIOPORTAL)

    assert FederatedPortal.sync!({})
    assert_empty FederatedPortal.as_config
  end

  test 'updates a portal already stored instead of duplicating it' do
    FederatedPortal.sync!(bioportal: BIOPORTAL)
    FederatedPortal.sync!(bioportal: BIOPORTAL.merge(apikey: '99999999-9999-9999-9999-999999999999'))

    assert_equal 1, FederatedPortal.count
    assert_equal '99999999-9999-9999-9999-999999999999', FederatedPortal.as_config.dig(:bioportal, :apikey)
  end

  test 'ignores a portal left without an apikey' do
    FederatedPortal.sync!(bioportal: BIOPORTAL.except(:apikey))

    assert_empty FederatedPortal.as_config
  end

  test 'ignores a portal whose apikey cannot be decrypted' do
    FederatedPortal.create!(portal_key: 'bioportal', name: 'BioPortal',
                            encrypted_apikey: 'written-under-another-secret')

    assert_empty FederatedPortal.as_config
  end
end
