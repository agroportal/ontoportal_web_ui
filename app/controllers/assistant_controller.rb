# Backend proxy for the smart assistant pop-up.
#
# The browser holds the dialogue and POSTs the whole conversation here on every turn.
# This action runs the LLM <-> MCP tool-calling loop server-side (so the LLM API key never
# reaches the browser) and streams the answer back as Server-Sent Events: `tool` events as
# tools are called, `token` events as the final answer is generated, then a `done` event.
class AssistantController < ApplicationController
  include ActionController::Live

  layout false

  # JSON body endpoint: don't let ParamsWrapper duplicate the body under an
  # `assistant` root key (which would log "Unpermitted parameter: :assistant").
  wrap_parameters format: []

  before_action :ensure_enabled
  before_action :require_signed_in

  # POST /assistant/chat  { messages: [{ role:, content: }, ...] }  ->  text/event-stream
  def chat
    conversation = params.permit(messages: %i[role content])[:messages]&.map(&:to_h) || []

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no' # disable proxy buffering (nginx)
    response.headers.delete('Content-Length')

    if conversation.empty?
      sse(:error, message: t('assistant.error'))
      return
    end

    AssistantService.new(user_apikey: get_apikey).run_stream(conversation) do |type, payload|
      case type
      when :tool  then sse(:tool, name: payload)
      when :token then sse(:token, text: payload)
      when :done  then sse(:done, reply: payload)
      end
    end
  rescue McpClient::Error, LlmClient::Error, AssistantService::Error => e
    Rails.logger.error("[assistant] #{e.class}: #{e.message}")
    sse(:error, message: t('assistant.error'))
  rescue IOError, Errno::EPIPE
    # client disconnected mid-stream — nothing to do
  rescue StandardError => e
    Rails.logger.error("[assistant] #{e.class}: #{e.message}\n#{Array(e.backtrace).first(5).join("\n")}")
    sse(:error, message: t('assistant.error'))
  ensure
    response.stream.close
  end

  private

  def sse(event, data)
    response.stream.write("event: #{event}\n")
    response.stream.write("data: #{data.to_json}\n\n")
  rescue IOError, Errno::EPIPE
    # client disconnected
  end

  def ensure_enabled
    head :not_found unless assistant_enabled?
  end

  # 401 (rather than the HTML redirect of authorize_and_redirect) since this is XHR-only.
  def require_signed_in
    head :unauthorized if session[:user].nil?
  end
end
