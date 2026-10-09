# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

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
    submission = values.delete(:_submission) || OpenStruct.new(URI: nil, pullLocation: nil)
    ontology = LinkedData::Client::Models::Ontology.new(values: { acronym: acronym, viewingRestriction: visibility, **values })
    explore = Object.new
    explore.define_singleton_method(:latest_submission) { |*_args| submission }
    ontology.define_singleton_method(:explore) { explore }
    ontology
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

  test 'assesses the declared ontology URI rather than the portal URL' do
    stub_request(:post, $FOOPS_URL).to_return(status: 200, body: +'{"overall_score": 1.0, "checks": []}')

    submission = OpenStruct.new(URI: 'https://w3id.org/earthsemantics/OSO',
                                pullLocation: 'https://example.org/OSO.ttl')
    get_foops_score(ontology('OSO', 'public', _submission: submission))

    assert_requested :post, $FOOPS_URL, times: 1 do |request|
      request.body.include?('https://w3id.org/earthsemantics/OSO')
    end
  end

  test 'falls back to the pull location when no URI is declared' do
    submission = OpenStruct.new(URI: nil, pullLocation: 'https://example.org/OSO.ttl')

    assert_equal 'https://example.org/OSO.ttl', foops_ontology_uri(ontology('OSO', 'public', _submission: submission))
  end

  test 'falls back to the portal ontology URI when nothing is declared' do
    assert_equal "#{$UI_URL}/ontologies/OSO", foops_ontology_uri(ontology('OSO', 'public'))
  end

  test 'falls back to the portal ontology URI when the submission lookup fails' do
    ontology = ontology('OSO', 'public')
    ontology.explore.define_singleton_method(:latest_submission) { |*_args| raise StandardError }

    assert_equal "#{$UI_URL}/ontologies/OSO", foops_ontology_uri(ontology)
  end
end
