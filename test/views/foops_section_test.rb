# frozen_string_literal: true

require 'test_helper'

class FoopsSectionTest < ActionView::TestCase
  include FairScoreHelper

  # A FOOPS! report as the API stores it
  REPORT = {
    'overall_score' => 0.5,
    'checks' => [{ 'abbreviation' => 'FIND1', 'principle_id' => 'F1', 'title' => 'Persistent URI',
                   'total_passed_tests' => 1, 'total_tests_run' => 2 }]
  }.freeze

  test 'renders the stored score without waiting for the async call' do
    @ontology = LinkedData::Client::Models::Ontology.new(values: { acronym: 'PUB', viewingRestriction: 'public' })
    @foops_scores_data = create_foops_raw_scores_data(REPORT)
    # The section renders `fairs_score` relative to the ontologies views
    controller.controller_path = 'ontologies'

    render partial: 'ontologies/sections/metadata/ontology_foops_section', locals: { acronym: 'PUB' }

    assert_select '#foops-total-score', text: /50\.0/
  end
end
