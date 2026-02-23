class SubscriptionsController < ApplicationController

  def create
    ontology_id = params[:ontology_id]
    raise Exception, "Missing ontology_id" if ontology_id.blank?

    # Resolve the ontology acronym
    if ontology_id.start_with?('http')
      ont = LinkedData::Client::Models::Ontology.find(ontology_id)
      acronym = ont&.acronym
    else
      acronym = ontology_id.split('/').last
    end
    raise Exception, "Ontology not found" if acronym.blank?

    # Send PATCH request to backend /subscriptions endpoint as JSON
    api_url = URI.parse("#{$REST_URL}/subscriptions")
    http = Net::HTTP.new(api_url.host, api_url.port)
    http.use_ssl = api_url.scheme == 'https'

    request = Net::HTTP::Patch.new(api_url.request_uri)
    request['Authorization'] = "apikey token=#{helpers.get_apikey}"
    request['Content-Type'] = 'application/json'
    request['Cache-Control'] = 'no-cache'
    request.body = { ontology: acronym, notification_type: 3 }.to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      # Update session user subscriptions if available
      if session[:user]
        user = LinkedData::Client::Models::User.find(session[:user].id, include: 'all')
        session[:user].subscription = user.subscription if user
      end

      render json: { updated_sub: true }
    else
      render json: { updated_sub: false, error: response.body }, status: :unprocessable_entity
    end
  rescue => e
    render json: { updated_sub: false, error: e.message }, status: :unprocessable_entity
  end

end
