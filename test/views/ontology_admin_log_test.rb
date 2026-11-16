# frozen_string_literal: true

require 'test_helper'

class OntologyAdminLogTest < ActionView::TestCase
  # Log lines quote the uploaded file: its name, the parser errors
  MESSAGE = 'Parsing <img src=x onerror=alert(1)>.owl'
  # Status codes of the latest submission
  FAILED = %w[UPLOADED ERROR_RDF].freeze
  READY = %w[UPLOADED RDF RDF_LABELS].freeze

  setup do
    @ontology = OpenStruct.new(acronym: 'STY')
  end

  test 'escapes the messages of the parse log' do
    @latest_submission = OpenStruct.new(submissionStatus: FAILED)
    @log = [entry('ERROR', MESSAGE)]

    render partial: 'ontologies/admin/log'

    assert_select 'span.text-danger', text: 'ERROR:'
    assert_select 'img', count: 0
    assert_includes rendered, ERB::Util.html_escape(MESSAGE)
  end

  # The status tells, not the log: a failed processing may log no ERROR line
  test 'lists the log when the status of the latest submission has an error' do
    @latest_submission = OpenStruct.new(submissionStatus: FAILED)
    @log = [entry('INFO', 'Parsing STY/2')]

    render partial: 'ontologies/admin/log'

    assert_includes rendered, 'Parsing STY/2'
  end

  test 'says when the status of the latest submission has no errors' do
    @latest_submission = OpenStruct.new(submissionStatus: READY)
    @log = [entry('ERROR', 'Missing label for STY/T001')]

    render partial: 'ontologies/admin/log'

    assert_select 'p', text: 'The processing log for the latest submission of ontology STY contains no errors.'
    assert_not_includes rendered, 'Missing label for STY/T001'
  end

  # The General section always shows the log
  test 'links the download of the log' do
    render partial: 'ontologies/admin/general'

    assert_select "a[href='/ontologies/STY/administration/log.txt'][title='Download the log']"
  end

  private

  # As the API client returns the entries of /ontologies/:acronym/admin/log
  def entry(severity, message)
    OpenStruct.new(timestamp: '2026-11-16 10:00:00', severity: severity, message: message)
  end
end
