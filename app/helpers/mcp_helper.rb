# frozen_string_literal: true

# The MCP page: the server that lets AI assistants query the SPARQL endpoint.
module McpHelper
  # Example questions, grouped by the mistake they provoke. Texts live under mcp.examples in the locales.
  EXAMPLES = {
    content: %w[milling_narrower maize_labels crushing_definition air_temperature_variables],
    size: %w[plants_classes largest_in_group],
    catalogue: %w[soil_inrae wheat_licenses],
    people: %w[ror_organizations],
    links: %w[shared_projects],
    missing: %w[missing_license failed_parse]
  }.freeze

  TOOLS = %w[get_schema_card resolve_ontology run_sparql list_terms].freeze

  # The server name clients show in their tool lists.
  CLIENT_SERVER_NAME = 'agroportal'

  # AgroPortal's server. Deployed portals keep their own config file, so the page
  # must work when it never mentions $MCP_URL; setting it points the page elsewhere.
  DEFAULT_URL = 'https://mcp.agroportal.eu/'

  def mcp_url
    $MCP_URL.presence || DEFAULT_URL
  end

  # One setup snippet per client. Commands and config files are not translated.
  def mcp_client_setups(url)
    [
      { client: 'claude_code', code: "claude mcp add --transport http #{CLIENT_SERVER_NAME} #{url}" },
      { client: 'opencode', code: "opencode mcp add #{CLIENT_SERVER_NAME} --url #{url}" },
      { client: 'vscode', code: JSON.pretty_generate(servers: { CLIENT_SERVER_NAME => { type: 'http', url: url } }) }
    ]
  end
end
