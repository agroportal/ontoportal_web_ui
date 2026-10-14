# frozen_string_literal: true

# The MCP page: the server that lets AI assistants query the SPARQL endpoint.
module McpHelper
  # Example questions, grouped by the mistake they provoke. Texts live under mcp.examples in the locales.
  EXAMPLES = {
    content: %w[crushing_definition milling_narrower maize_labels],
    size: %w[plants_classes largest_in_group],
    catalogue: %w[soil_inrae wheat_licenses],
    people: %w[ror_organizations],
    links: %w[shared_projects],
    missing: %w[missing_license failed_parse]
  }.freeze

  TOOLS = %w[get_schema_card resolve_ontology run_sparql list_terms].freeze

  # The server name clients show in their tool lists.
  CLIENT_SERVER_NAME = 'agroportal'

  def mcp_enabled?
    $MCP_URL.present?
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
