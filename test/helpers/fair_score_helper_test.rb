# frozen_string_literal: true

require 'test_helper'

class FairScoreHelperTest < ActionView::TestCase
  include FairScoreHelper

  REST_URL = 'http://api.test'

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    define_singleton_method(:foops_enabled?) { true }
    # Keep the stored-report lookup off the live API, so these stay unit tests.
    define_singleton_method(:rest_url) { REST_URL }
    define_singleton_method(:get_apikey) { 'test-apikey' }
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

  def stored_report_url(acronym)
    "#{REST_URL}/ontologies/#{acronym}/foops"
  end

  def stub_no_stored_report(acronym)
    stub_request(:get, stored_report_url(acronym)).to_return(status: 404, body: '')
  end

  # A report FOOPS! answers for an ontology it could actually download.
  def foops_report(overall_score, rdf1_status: 'ok')
    { 'overall_score' => overall_score,
      'checks' => [{ 'abbreviation' => 'RDF1', 'status' => rdf1_status }] }
  end

  test 'private ontologies are assessed like any other' do
    assert foops_assessable?(ontology('PRIV', 'private'))
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

  test 'reads the stored report of a private ontology' do
    stub_request(:get, stored_report_url('PRIV'))
      .to_return(status: 200, body: foops_report(0.42).to_json)

    score = get_foops_score(ontology('PRIV', 'private'))

    assert_equal 0.42, score['overall_score']
  end

  test 'reads the report stored by the backend instead of calling FOOPS!' do
    stub_request(:get, stored_report_url('PUB'))
      .to_return(status: 200, body: +foops_report(0.8).to_json)
    stub_request(:post, $FOOPS_URL)

    score = get_foops_score(ontology('PUB', 'public'))

    assert_equal 0.8, score['overall_score']
    assert_not_requested :post, $FOOPS_URL
  end

  test 'falls back to FOOPS! when the backend stores no report' do
    stub_no_stored_report('PUB')
    stub_request(:post, $FOOPS_URL).to_return(status: 200, body: +foops_report(0.5).to_json)

    score = get_foops_score(ontology('PUB', 'public'))

    assert_equal 0.5, score['overall_score']
    assert_requested :post, $FOOPS_URL, times: 1
  end

  test 'discards a live report whose RDF1 check did not pass' do
    stub_no_stored_report('PUB')
    stub_request(:post, $FOOPS_URL)
      .to_return(status: 200, body: +foops_report(0.5, rdf1_status: 'error').to_json)

    assert_empty get_foops_score(ontology('PUB', 'public'))
  end
end
