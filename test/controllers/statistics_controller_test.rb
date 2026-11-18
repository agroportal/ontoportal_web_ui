# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

# Slice requests send NCBO-Slice, so the API scopes the statistics to the
# slice's ontologies. Only the main domain may fill the portal-wide cache.
class StatisticsControllerTest < ActiveSupport::TestCase
  CACHE_KEY = "statistics_index_data-#{$SITE}".freeze
  MAIN_DOMAIN = { active: false, name: '', acronym: '' }.freeze
  SLICE = { active: true, name: 'INRAE', acronym: 'inrae' }.freeze
  API_MODELS = [LinkedData::Client::Models::Project,
                LinkedData::Client::Models::User,
                LinkedData::Client::Models::Agent].freeze
  ANALYTICS = [{ [2024, 1] => ['STY'] }, { [2024, 1] => 3 }].freeze

  setup do
    @cache = ActiveSupport::Cache::MemoryStore.new
  end

  # Stub each model's `all` in turn, e.g. Project { User { Agent { yield } } }
  def stub_api(models = API_MODELS, &block)
    return yield if models.empty?

    models.first.stub(:all, []) { stub_api(models.drop(1), &block) }
  end

  # Answer every API call locally so the test never reaches the network.
  def render_statistics(subdomain_filter)
    controller = StatisticsController.new
    controller.instance_variable_set(:@subdomain_filter, subdomain_filter)
    controller.define_singleton_method(:ontologies_by_year_month) { ANALYTICS }

    Rails.stub(:cache, @cache) { stub_api { controller.index } }
  end

  test 'caches the main domain statistics' do
    render_statistics(MAIN_DOMAIN)

    assert @cache.exist?(CACHE_KEY)
  end

  test 'does not cache slice statistics' do
    render_statistics(SLICE)

    refute @cache.exist?(CACHE_KEY)
  end
end
