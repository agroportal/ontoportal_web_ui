require 'net/http'
require 'json'
require 'uri'

# Minimal client for an OpenAI-compatible Chat Completions endpoint.
#
# Works with any provider exposing the OpenAI `/chat/completions` contract
# (OpenAI, Azure OpenAI, vLLM, Mistral, Together, Groq, …), including native
# `tools` function-calling.
class LlmClient
  class Error < StandardError; end

  DEFAULT_TIMEOUT = 90

  def initialize(api_url:, api_key:, model:, timeout: DEFAULT_TIMEOUT)
    raise Error, 'LLM endpoint is not configured' if api_url.to_s.strip.empty?
    raise Error, 'LLM model is not configured' if model.to_s.strip.empty?

    @api_url = api_url
    @api_key = api_key
    @model = model
    @timeout = timeout
  end

  # messages: array of {role:, content:, ...}
  # tools:    OpenAI tools array (optional). When present, tool_choice is "auto".
  # stop:     optional array of stop sequences.
  # Returns the assistant `message` hash from the first choice.
  def chat(messages:, tools: nil, stop: nil)
    body = { model: @model, messages: messages }
    if tools && !tools.empty?
      body[:tools] = tools
      body[:tool_choice] = 'auto'
    end
    body[:stop] = stop if stop && !stop.empty?

    payload = post_json(completions_uri, body)
    message = payload.dig('choices', 0, 'message')
    raise Error, "LLM response had no message: #{payload.to_json[0, 300]}" if message.nil?

    message
  end

  # Streams a completion. Yields each `delta.content` piece as it arrives and returns the
  # full accumulated content. `delta.reasoning_content` (emitted by reasoning models) is
  # ignored — only the user-facing answer is yielded.
  def stream_chat(messages:, stop: nil)
    body = { model: @model, messages: messages, stream: true }
    body[:stop] = stop if stop && !stop.empty?

    uri = URI.parse(completions_uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = @timeout
    http.read_timeout = @timeout

    req = Net::HTTP::Post.new(uri.request_uri)
    req['Content-Type'] = 'application/json'
    req['Accept'] = 'text/event-stream'
    req['Authorization'] = "Bearer #{@api_key}" unless @api_key.to_s.empty?
    req.body = body.to_json

    full = +''
    buffer = +''
    http.request(req) do |response|
      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "LLM endpoint returned #{response.code}: #{response.read_body.to_s[0, 300]}"
      end

      response.read_body do |chunk|
        buffer << chunk
        while (nl = buffer.index("\n"))
          line = buffer.slice!(0..nl).chomp
          next unless line.start_with?('data:')

          data = line.sub(/\Adata:\s*/, '')
          next if data.empty? || data == '[DONE]'

          piece = (JSON.parse(data) rescue nil)&.dig('choices', 0, 'delta', 'content')
          next if piece.nil? || piece.empty?

          full << piece
          yield piece if block_given?
        end
      end
    end
    full
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise Error, "LLM endpoint timed out after #{@timeout}s"
  rescue SocketError, SystemCallError => e
    raise Error, "LLM endpoint unreachable: #{e.message}"
  end

  private

  # Accept either a base URL (e.g. ".../v1") or a full ".../chat/completions" URL.
  def completions_uri
    base = @api_url.to_s.sub(%r{/+\z}, '')
    base.end_with?('/chat/completions') ? base : "#{base}/chat/completions"
  end

  def post_json(uri_string, body)
    uri = URI.parse(uri_string)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = @timeout
    http.read_timeout = @timeout

    req = Net::HTTP::Post.new(uri.request_uri)
    req['Content-Type'] = 'application/json'
    req['Authorization'] = "Bearer #{@api_key}" unless @api_key.to_s.empty?
    req.body = body.to_json

    response = http.request(req)
    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "LLM endpoint returned #{response.code}: #{response.body.to_s[0, 300]}"
    end

    JSON.parse(response.body)
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise Error, "LLM endpoint timed out after #{@timeout}s"
  rescue SocketError, SystemCallError => e
    raise Error, "LLM endpoint unreachable: #{e.message}"
  rescue JSON::ParserError => e
    raise Error, "Invalid LLM response: #{e.message}"
  end
end
