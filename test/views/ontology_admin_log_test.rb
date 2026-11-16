# frozen_string_literal: true

require 'test_helper'

class OntologyAdminLogTest < ActionView::TestCase
  # Log lines quote the uploaded file: its name, the parser errors
  MESSAGE = 'Parsing <img src=x onerror=alert(1)>.owl'

  test 'escapes the messages of the parse log' do
    # As the API client returns the entries of /ontologies/:acronym/admin/log
    @log = [OpenStruct.new(timestamp: '2026-11-16 10:00:00', severity: 'ERROR', message: MESSAGE)]

    render partial: 'ontologies/admin/log'

    assert_select 'span.text-danger', text: 'ERROR:'
    assert_select 'img', count: 0
    assert_includes rendered, ERB::Util.html_escape(MESSAGE)
  end

  test 'says when the log contains no errors' do
    @ontology = OpenStruct.new(acronym: 'STY')
    @log = [OpenStruct.new(timestamp: '2026-11-16 10:00:00', severity: 'INFO', message: 'Parsed STY/2')]

    render partial: 'ontologies/admin/log'

    assert_select 'p', text: 'The processing log for the latest submission of ontology STY contains no errors.'
    assert_not_includes rendered, 'Parsed STY/2'
  end

  # The General section always shows the log
  test 'links the download of the log' do
    @ontology = OpenStruct.new(acronym: 'STY')

    render partial: 'ontologies/admin/general'

    assert_select "a[href='/ontologies/STY/administration/log.txt'][title='Download the log']"
  end
end
