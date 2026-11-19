# frozen_string_literal: true

# Explains the MCP server that lets AI assistants query the SPARQL endpoint, and how to connect to it.
class McpController < ApplicationController
  layout :determine_layout

  def index
    @mcp_url = helpers.mcp_url
    @title = t('mcp.title')
  end
end
