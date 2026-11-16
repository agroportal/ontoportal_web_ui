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
end
