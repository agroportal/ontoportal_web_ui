# frozen_string_literal: true

require 'test_helper'

class MultiLanguagesHelperTest < ActionView::TestCase
  include MultiLanguagesHelper

  setup do
    session[:locale] = :en
  end

  def submission(*languages)
    OpenStruct.new(naturalLanguage: languages.map { |lang| "http://lexvo.org/id/iso639-1/#{lang}" })
  end

  test 'keeps the requested language when the ontology provides it' do
    assert_equal 'EN', request_lang(submission('en', 'fr'))

    params[:lang] = 'fr'
    assert_equal 'FR', request_lang(submission('en', 'fr'))
  end

  test 'falls back to the first language of an ontology missing the requested one' do
    assert_equal 'PT-BR', request_lang(submission('pt-br'))

    params[:language] = 'fr'
    assert_equal 'PT-BR', request_lang(submission('pt-br'))
  end

  test 'prefers a regional variant of the requested language' do
    assert_equal 'EN-US', request_lang(submission('pt-br', 'en-us'))
  end

  test 'keeps the requested language when the ontology declares none' do
    assert_equal 'EN', request_lang(OpenStruct.new)
  end

  test 'keeps the all languages selection' do
    params[:language] = 'all'
    assert_equal 'ALL', request_lang(submission('pt-br'))
  end

  test 'gathers the available languages from every given submission' do
    assert_equal %w[FR PT-BR], available_content_languages(submission('fr'), submission('pt-br'))
    assert_equal %w[PT-BR], available_content_languages(nil, submission('pt-br'))
  end
end
