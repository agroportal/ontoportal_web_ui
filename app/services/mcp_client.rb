require 'net/http'
require 'json'
require 'uri'

# Minimal JSON-RPC 2.0 client for the AgroPortal MCP server (Streamable HTTP transport).
#
# The server is stateless — each call is an independent POST, no session id is needed.
# Authentication is the signed-in user's AgroPortal API key, sent via the
# `X-Agroportal-User-Apikey` header.
class McpClient
  class Error < StandardError; end

  DEFAULT_TIMEOUT = 30

  def initialize(server_url:, apikey:, timeout: DEFAULT_TIMEOUT)
    raise Error, 'MCP server URL is not configured' if server_url.to_s.strip.empty?

    @uri = URI.parse(server_url)
    @apikey = apikey
    @timeout = timeout
    @id = 0
  end

  # Raw list of MCP tool definitions ({ "name", "description", "inputSchema" }).
  def list_tools
    Array(request('tools/list')['tools'])
  end

  # MCP tool definitions mapped to the OpenAI "tools" (function-calling) format.
  # An MCP `inputSchema` is JSON Schema, which is exactly what OpenAI expects for
  # a function's `parameters`.
  def tools_for_openai
    list_tools.map do |tool|
      {
        type: 'function',
        function: {
          name: tool['name'],
          description: tool['description'].to_s,
          parameters: tool['inputSchema'] || { 'type' => 'object', 'properties' => {} }
        }
      }
    end
  end

  # Invokes a tool and returns its textual result (joined text content parts).
  def call_tool(name, arguments = {})
    result = request('tools/call', { name: name, arguments: arguments || {} })
    extract_text(result)
  end

  private

  def extract_text(result)
    text = Array(result['content']).map do |part|
      part.is_a?(Hash) ? (part['text'] || part['data'] || part.to_json) : part.to_s
    end.join("\n").strip

    text.empty? ? result.to_json : text
  end

  def request(method, params = nil)
    @id += 1
    body = { jsonrpc: '2.0', id: @id, method: method }
    body[:params] = params if params

    response = post(body)

    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "MCP server returned #{response.code}: #{response.body.to_s[0, 300]}"
    end

    payload = parse_response(response)
    if payload['error']
      raise Error, "MCP error #{payload.dig('error', 'code')}: #{payload.dig('error', 'message')}"
    end

    payload['result'] || {}
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise Error, "MCP server timed out after #{@timeout}s"
  rescue SocketError, SystemCallError => e
    raise Error, "MCP server unreachable: #{e.message}"
  end

  def post(body)
    http = Net::HTTP.new(@uri.host, @uri.port)
    http.use_ssl = (@uri.scheme == 'https')
    http.open_timeout = @timeout
    http.read_timeout = @timeout

    req = Net::HTTP::Post.new(@uri.request_uri)
    req['Content-Type'] = 'application/json'
    req['Accept'] = 'application/json, text/event-stream'
    req['X-Agroportal-User-Apikey'] = @apikey.to_s
    req.body = body.to_json

    http.request(req)
  end

  # Handles both application/json and text/event-stream (SSE) responses.
  def parse_response(response)
    raw = response.body.to_s

    if response['content-type'].to_s.include?('text/event-stream')
      raw.each_line.filter_map do |line|
        line = line.strip
        next unless line.start_with?('data:')

        JSON.parse(line.sub(/\Adata:\s*/, '')) rescue nil
      end.last || {}
    else
      JSON.parse(raw)
    end
  rescue JSON::ParserError => e
    raise Error, "Invalid MCP response: #{e.message}"
  end
end
