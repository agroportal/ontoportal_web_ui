# Backend proxy for the smart assistant pop-up.
#
# The browser holds the dialogue and POSTs the whole conversation here on every turn.
# This action runs the LLM <-> MCP tool-calling loop server-side (so the LLM API key never
# reaches the browser) and returns the final answer plus the trace of tools that were used.
class AssistantController < ApplicationController
  layout false

  # JSON-only endpoint: don't let ParamsWrapper duplicate the body under an
  # `assistant` root key (which would log "Unpermitted parameter: :assistant").
  wrap_parameters format: []

  before_action :ensure_enabled
  before_action :require_signed_in

  # POST /assistant/chat  { messages: [{ role:, content: }, ...] }
  def chat
    conversation = params.permit(messages: %i[role content])[:messages]&.map(&:to_h) || []
    if conversation.empty?
      render json: { error: t('assistant.error') }, status: :unprocessable_entity
      return
    end

    result = AssistantService.new(user_apikey: get_apikey).run(conversation)
    render json: result
  rescue McpClient::Error, LlmClient::Error, AssistantService::Error => e
    Rails.logger.error("[assistant] #{e.class}: #{e.message}")
    render json: { error: t('assistant.error') }, status: :bad_gateway
  rescue StandardError => e
    Rails.logger.error("[assistant] #{e.class}: #{e.message}\n#{Array(e.backtrace).first(5).join("\n")}")
    render json: { error: t('assistant.error') }, status: :internal_server_error
  end

  private

  def ensure_enabled
    head :not_found unless assistant_enabled?
  end

  # JSON 401 (rather than the HTML redirect of authorize_and_redirect) since this is XHR-only.
  def require_signed_in
    return unless session[:user].nil?

    render json: { error: t('assistant.signed_out') }, status: :unauthorized
  end
end
