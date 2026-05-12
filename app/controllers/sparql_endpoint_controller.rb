class SparqlEndpointController < ApplicationController
  layout :determine_layout
  before_action :check_sparql_enabled

  include SparqlHelper
  def index
  end

  def edit_sample_queries
    if params[:graph].nil?
      @sample_queries = helpers.get_catalog_sample_queries
    else
      @sample_queries = helpers.get_ontology_sample_queries(params[:graph])
      @graph = params[:graph].gsub($REST_URL, 'http://data.bioontology.org')
    end
    render partial: 'sample_queries_edit_modal',layout: false
  end

  def generate_query
    unless helpers.ai_sparql_enabled?
      render json: { error: 'AI SPARQL generator is not configured' }, status: :service_unavailable
      return
    end

    prompt = params[:prompt].to_s.strip
    if prompt.blank?
      render json: { error: 'Prompt is required' }, status: :bad_request
      return
    end

    begin
      sparql = helpers.generate_sparql_from_prompt(prompt, graph: params[:graph], current_query: params[:current_query])
      render json: { query: sparql }
    rescue StandardError => e
      logger.error "AI SPARQL generation failed: #{e.message}"
      render json: { error: e.message.presence || 'Failed to generate query' }, status: :bad_gateway
    end
  end

  private

  def check_sparql_enabled
    unless helpers.sparql_enabled?
      redirect_to root_path, alert: 'SPARQL endpoint is not available'
    end
  end
end