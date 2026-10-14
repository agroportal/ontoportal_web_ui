# frozen_string_literal: true

# Explains the MCP server that lets AI assistants query the SPARQL endpoint, and how to connect to it.
class McpController < ApplicationController
  layout :determine_layout
  before_action :check_mcp_enabled

  def index
    @mcp_url = $MCP_URL
    @title = t('mcp.title')
  end

  private

  def check_mcp_enabled
    return if helpers.mcp_enabled?

    redirect_to root_path, alert: t('mcp.unavailable')
  end
end
