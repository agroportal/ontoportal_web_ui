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

  def ontology(acronym, visibility, **values)
    LinkedData::Client::Models::Ontology.new(values: { acronym: acronym, viewingRestriction: visibility, **values })
  end

  def with_not_downloadable(acronyms)
    original = $NOT_DOWNLOADABLE
    $NOT_DOWNLOADABLE = acronyms
    yield
  ensure
    $NOT_DOWNLOADABLE = original
  end

  test 'private ontologies cannot be assessed by FOOPS!' do
    refute foops_assessable?(ontology('PRIV', 'private'))
    assert foops_assessable?(ontology('PUB', 'public'))
  end

  test 'ontologies without a downloadable file cannot be assessed by FOOPS!' do
    refute foops_assessable?(ontology('SUMMARY', 'public', summaryOnly: true))

    with_not_downloadable(['LOCKED']) do
      refute foops_assessable?(ontology('LOCKED', 'public'))
      assert foops_assessable?(ontology('PUB', 'public'))
    end
  end

  test 'does not call FOOPS! for an ontology without a downloadable file' do
    stub_request(:post, $FOOPS_URL)

    score = get_foops_score(ontology('SUMMARY', 'public', summaryOnly: true))

    assert_includes score['error'], I18n.t('fair_score.foops_no_file_hint')
    assert_not_requested :post, $FOOPS_URL
  end

  test 'does not call FOOPS! for a private ontology' do
    stub_request(:post, $FOOPS_URL)

    private_ontology = ontology('PRIV', 'private')
    score = get_foops_score(private_ontology)

    assert_equal({ 'error' => foops_blocked_message(private_ontology) }, score)
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
