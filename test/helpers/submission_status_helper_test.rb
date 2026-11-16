# frozen_string_literal: true

require 'test_helper'

class SubmissionStatusHelperTest < ActionView::TestCase
  DETAILS_URL = '/ontologies/STY/administration/submissions/4'

  # The API returns the codes in no particular order
  def submission(*codes)
    OpenStruct.new(submissionId: 4, submissionStatus: codes)
  end

  def pill(*codes)
    Nokogiri::HTML.fragment(view.submission_state_pill(submission(*codes), DETAILS_URL)).at_css('a.submission-state')
  end

  def stages(*codes)
    view.submission_stages(submission(*codes)).to_h { |stage| [stage.name, stage] }
  end

  test 'labels the pill with the overall state' do
    assert_equal 'Ready', pill('UPLOADED', 'RDF', 'INDEXED').at_css('span').text
    assert_equal 'Failed at Parse', pill('UPLOADED', 'ERROR_RDF').at_css('span').text
    assert_equal 'Failed at Metrics', pill('RDF', 'RDF_LABELS', 'ERROR_METRICS').at_css('span').text
    assert_equal 'Archived', pill('ARCHIVED').at_css('span').text
    assert_equal 'Not parsed', pill('UPLOADED').at_css('span').text
  end

  # As the banner atop the ontology page: red before parsing, orange after
  test 'colors the pill as the ontology page banner' do
    assert_includes pill('UPLOADED', 'ERROR_RDF')['class'], 'submission-state--failed'
    assert_includes pill('RDF', 'RDF_LABELS', 'ERROR_METRICS')['class'], 'submission-state--partly_failed'
    assert_includes pill('UPLOADED')['class'], 'submission-state--not_parsed'
    assert_includes pill('RDF', 'RDF_LABELS')['class'], 'submission-state--ready'
  end

  # The admin page shows the processing logs only then
  test 'tells when a step of the submission failed' do
    assert view.submission_failed?(submission('UPLOADED', 'ERROR_RDF'))
    assert view.submission_failed?(submission('RDF', 'RDF_LABELS', 'ERROR_METRICS'))

    assert_not view.submission_failed?(submission('RDF', 'RDF_LABELS', 'INDEXED'))
    assert_not view.submission_failed?(submission('UPLOADED'))
    assert_not view.submission_failed?(submission('ARCHIVED'))
    assert_not view.submission_failed?(nil)
  end

  test 'opens the details in the application modal on click' do
    link = pill('RDF', 'ERROR_METRICS')

    assert_equal DETAILS_URL, link['href']
    assert_equal 'click->show-modal#show', link['data-action']
    assert_equal 'application_modal_content', link['data-turbo-frame']
    assert_includes link['class'], 'submission-state--failed'
  end

  test 'gives each stage the outcome of its steps' do
    stages = stages('UPLOADED', 'RDF', 'RDF_LABELS', 'OBSOLETE', 'INDEXED', 'ERROR_INDEXED_PROPERTIES')
    index_steps = stages['Index'].steps.to_h { |step| [step.code, step.outcome] }

    assert_equal %w[Parse Index Metrics Annotator Diff FAIR], stages.keys
    assert_equal %i[done failed not_run], stages.values_at('Parse', 'Index', 'Metrics').map(&:outcome)
    assert_equal({ 'INDEXED' => :done, 'INDEXED_PROPERTIES' => :failed, 'INDEXED_ALL_DATA' => :not_run }, index_steps)
  end

  test 'lists the TDv5 check only when it fails' do
    assert_not_includes stages('UPLOADED', 'RDF')['Parse'].steps.map(&:code), 'TDV5'
    assert_includes stages('UPLOADED', 'ERROR_TDV5')['Parse'].steps.map(&:code), 'TDV5'
  end

  test 'lists no stage for an archived submission' do
    assert_empty stages('ARCHIVED')
  end

  test 'gathers unknown statuses in an extra stage' do
    other = stages('RDF', 'ERROR_NEW_STEP')['Other']

    assert_equal :failed, other.outcome
    assert_equal ['NEW_STEP'], other.steps.map(&:code)
  end
end
