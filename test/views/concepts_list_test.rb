# frozen_string_literal: true

require 'test_helper'

class ConceptsListTest < ActionView::TestCase
  COLLECTION_ID = 'http://opendata.inrae.fr/thesaurusINRAE/gr_6c79e7c5'
  CONCEPT_ID = 'http://opendata.inrae.fr/thesaurusINRAE/c_1912c90c'

  # A shared link must list the members in its language, on its concept
  test 'loads the linked collection in the requested language and concept' do
    @ontology = OpenStruct.new(acronym: 'INRAETHES')
    @collections = [{ '@id' => COLLECTION_ID, 'prefLabel' => 'coll DEFINED CONCEPTS' }]
    params[:concept_collections] = COLLECTION_ID
    params[:conceptid] = CONCEPT_ID
    params[:language] = 'fr'

    render partial: 'ontologies/concepts_browsers/concepts_list'

    assert_select 'turbo-frame#concepts_list_view-page-1[src*=?]', 'language=FR'
    assert_select 'turbo-frame#concepts_list_view-page-1[src*=?]', "conceptid=#{CGI.escape(CONCEPT_ID)}"
  end
end
