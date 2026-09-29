# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  ACRONYM = 'INRAETHES'
  COLLECTION_ID = 'http://opendata.inrae.fr/thesaurusINRAE/gr_6c79e7c5'
  FIRST_ID = 'http://opendata.inrae.fr/thesaurusINRAE/c_9fdfefff'
  REQUESTED_ID = 'http://opendata.inrae.fr/thesaurusINRAE/c_1912c90c'

  test 'keeps the requested language in the next page of members' do
    get_members(language: 'fr')

    assert_select 'turbo-frame#concepts_list_view-page-2[src*=?]', 'language=FR'
  end

  # The page already shows the requested concept: clicking it again would
  # reload it, and clicking another member would replace it
  test 'selects the requested member without clicking it' do
    get_members(language: 'fr', conceptid: REQUESTED_ID)

    assert_select 'a.tree-link.active[id=?]', REQUESTED_ID
    assert_select '[data-simple-tree-auto-click-value=?]', 'false'
  end

  # Links to a collection's members name no concept: show the first one
  test 'clicks the first member when no concept is requested' do
    get_members(language: 'fr')

    assert_select 'a.tree-link.active[id=?]', FIRST_ID
    assert_select '[data-simple-tree-auto-click-value=?]', 'true'
  end

  private

  # Serves one page of two members, FIRST_ID sorting first by label
  def get_members(**params)
    members = [OpenStruct.new(id: REQUESTED_ID, prefLabel: 'apprentissage antagoniste'),
               OpenStruct.new(id: FIRST_ID, prefLabel: 'accès libre')]
    page = OpenStruct.new(collection: members, page: 1, nextPage: 2)
    collection = api_stub(explore: api_stub(members: page))
    ontology = OpenStruct.new(acronym: ACRONYM,
                              explore: api_stub(latest_submission: OpenStruct.new, collections: collection))

    LinkedData::Client::Models::Ontology.stub(:find_by_acronym, [ontology]) do
      get '/ajax/classes/list', params: { ontology_id: ACRONYM, collectionid: COLLECTION_ID, **params }
    end
  end

  # Answers every call to each method with the same value, whatever the arguments
  def api_stub(**answers)
    Object.new.tap do |stub|
      answers.each { |name, answer| stub.define_singleton_method(name) { |*| answer } }
    end
  end
end
