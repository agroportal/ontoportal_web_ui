# frozen_string_literal: true

require 'test_helper'

class FairScoreHelperTest < ActionView::TestCase
  include FairScoreHelper

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    define_singleton_method(:foops_enabled?) { true }
  end

  teardown do
    Rails.cache = @original_cache
  end

  def ontology(acronym, visibility)
    LinkedData::Client::Models::Ontology.new(values: { acronym: acronym, viewingRestriction: visibility })
  end

  test 'private ontologies cannot be assessed by FOOPS!' do
    refute foops_assessable?(ontology('PRIV', 'private'))
    assert foops_assessable?(ontology('PUB', 'public'))
  end

  test 'does not call FOOPS! for a private ontology' do
    stub_request(:post, $FOOPS_URL)

    score = get_foops_score(ontology('PRIV', 'private'))

    assert_equal({ 'error' => foops_private_ontology_message }, score)
    assert_includes score['error'], $SITE.to_s
    assert_not_requested :post, $FOOPS_URL
  end

  test 'still calls FOOPS! for a public ontology' do
    stub_request(:post, $FOOPS_URL).to_return(status: 200, body: +'{"overall_score": 0.5, "checks": []}')

    score = get_foops_score(ontology('PUB', 'public'))

    assert_equal 0.5, score['overall_score']
    assert_requested :post, $FOOPS_URL, times: 1
  end
end
