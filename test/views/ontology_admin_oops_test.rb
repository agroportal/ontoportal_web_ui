# frozen_string_literal: true

require 'test_helper'

# The OOPS! section of the ontology admin page: the modelling pitfalls the
# submission pipeline found in the latest submission
class OntologyAdminOopsTest < ActionView::TestCase
  FRAME = 'turbo-frame#oops'
  # As GET /ontologies/STY/submissions/2/oops returns it, parsed by the API client
  REPORT = {
    total_pitfalls: 2, total_critical: 1, total_important: 0, total_minor: 1,
    pitfalls: [
      { code: 'P19', name: 'Defining multiple domains or ranges in properties',
        description: 'The domain or range of a property is defined twice.',
        importance: 'CRITICAL', affected_elements_total: 3 },
      { code: 'P08', name: 'Missing annotations', description: 'Elements lack a label or a comment.',
        importance: 'MINOR', affected_elements_total: 120 }
    ]
  }.freeze

  setup do
    @ontology = OpenStruct.new(acronym: 'STY', id: "#{LinkedData::Client.settings.rest_url}/ontologies/STY")
    @submission_id = 2
    session[:user] = OpenStruct.new(apikey: 'user-apikey')
  end

  test 'lists the pitfalls of the latest submission' do
    @report = JSON.parse(REPORT.to_json, object_class: OpenStruct)

    render partial: 'ontologies/admin/oops'

    assert_select "#{FRAME} p", text: '2 pitfalls found: 1 critical, 0 important, 1 minor.'
    assert_select "#{FRAME} tbody tr", count: 2
    assert_select "#{FRAME} tbody tr:first-child td:first-child", text: 'P19'
    assert_select "#{FRAME} .oops-importance--critical", text: 'CRITICAL'
    assert_select "#{FRAME} .oops-importance--minor", text: 'MINOR'
    assert_select "#{FRAME} tbody tr:last-child td:last-child", text: '120'

    # The raw report, from the API, with the key of the admin
    link = css_select("#{FRAME} a.btn").first
    assert_includes link['href'], "#{@ontology.id}/submissions/2/oops"
    assert_includes link['href'], 'apikey=user-apikey'
    assert_equal '_blank', link['target']
  end

  test 'says when the latest submission has no report' do
    @report = nil

    render partial: 'ontologies/admin/oops'

    assert_select "#{FRAME} p", text: 'No OOPS! report has been generated for the latest submission of this ontology.'
    assert_select "#{FRAME} table", count: 0
    assert_select "#{FRAME} a.btn", count: 0
  end
end
