# frozen_string_literal: true

module Rack
  # Tell the reverse proxy which user is logged in, so its access log can
  # record it (nginx logs $upstream_http_x_api_user and hides the header from
  # clients). Same header as the API's Rack::ApiUserHeader.
  class ApiUserHeader
    HEADER = 'x-api-user'

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      user = logged_in_user(env)
      headers[HEADER] = user.username.to_s if user.respond_to?(:username)

      [status, headers, body]
    end

    private

    # Read only a session the request already loaded: loading it here would
    # store a new session for every anonymous request that never used one
    # (assets, routing errors, crawlers).
    def logged_in_user(env)
      session = env[RACK_SESSION]
      return nil unless session&.loaded?

      session[:user]
    end
  end
end
