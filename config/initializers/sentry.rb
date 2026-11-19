# frozen_string_literal: true

# Report errors to Sentry, plus a share of the requests' traces and profiles.
if $SENTRY_DSN
  Sentry.init do |config|
    config.dsn = $SENTRY_DSN
    config.environment = $SENTRY_ENVIRONMENT || config.environment
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]

    # Span the API calls: the API client talks over Faraday + excon,
    # which the default patches (Net::HTTP only) don't see
    config.enabled_patches << :excon

    # Attach cookies, client IPs and request bodies: passwords included
    config.send_default_pii = true

    # Unset means off. e.g. 0.1 traces 10% of the requests
    config.traces_sample_rate = $SENTRY_TRACES_SAMPLE_RATE
    # Share of the traced requests that are also profiled
    config.profiles_sample_rate = $SENTRY_PROFILES_SAMPLE_RATE
  end
  Sentry.set_tags(application: 'ui')
end
