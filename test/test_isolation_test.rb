# frozen_string_literal: true

require 'test_helper'

class TestIsolationTest < ActiveSupport::TestCase
  # A user without an apikey, like the stand-in admins of the controller tests
  SIGNED_IN = { user: OpenStruct.new('admin?' => true) }.freeze

  # The API client adds the apikey of the session user to every call. A session left
  # in the thread broke the API calls of the next test, made before any request.
  test 'a test leaves no signed-in session to the next one' do
    # Signs in the way ApplicationController#set_global_thread_values does on each request
    signing_in = Class.new(ActiveSupport::TestCase) do
      test('signs in') { Thread.current[:session] = SIGNED_IN }
    end

    assert_predicate signing_in.new('test_signs_in').run, :passed?
    assert_nil Thread.current[:session]
  end
end
