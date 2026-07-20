# ontologies_api_client init (default config works for the UI)
require 'ontologies_api_client'
LinkedData::Client.config do |config|
  config.cache        = $CLIENT_REQUEST_CACHING
  config.rest_url     = $REST_URL
  config.purl_prefix  = $PURL_PREFIX
  config.debug_client = $DEBUG_RUBY_CLIENT || false
  config.debug_client_keys = $DEBUG_RUBY_CLIENT_KEYS || []
  config.apikey = $API_KEY
  # Federated portals are administered at runtime through the catalog, the connections
  # are opened from there: see FederationHelper#sync_federated_connections
  config.federated_portals = {}
end
