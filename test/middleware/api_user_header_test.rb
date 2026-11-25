# frozen_string_literal: true

require 'test_helper'

class ApiUserHeaderTest < ActiveSupport::TestCase
  HEADER = Rack::ApiUserHeader::HEADER
  User = Struct.new(:username)

  # Stands in for ActionDispatch::Request::Session once a controller used it
  class LoadedSession
    def initialize(data)
      @data = data
    end

    def loaded?
      true
    end

    def [](key)
      @data[key]
    end
  end

  # A session no controller touched: reading it would load (and store) it
  class UnloadedSession
    def loaded?
      false
    end

    def [](_key)
      raise 'the middleware loaded the session'
    end
  end

  test 'names the logged-in user' do
    headers = call(LoadedSession.new(user: User.new('john')))

    assert_equal 'john', headers[HEADER]
  end

  test 'no header for anonymous visitors' do
    assert_nil call(LoadedSession.new({}))[HEADER]
  end

  test 'leaves an unused session unloaded' do
    assert_nil call(UnloadedSession.new)[HEADER]
  end

  test 'runs inside the session middleware' do
    stack = Rails.application.middleware.map(&:klass)

    assert_operator stack.index(Rack::ApiUserHeader), :>, stack.index(ActionDispatch::Session::CacheStore)
  end

  private

  def call(session)
    app = ->(_env) { [200, {}, ['ok']] }
    _status, headers, _body = Rack::ApiUserHeader.new(app).call(Rack::RACK_SESSION => session)

    headers
  end
end
