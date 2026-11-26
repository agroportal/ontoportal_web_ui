# frozen_string_literal: true

require Rails.root.join('lib/rack/api_user_header').to_s

# Inside the session middleware, which it reads
Rails.application.config.middleware.use Rack::ApiUserHeader
