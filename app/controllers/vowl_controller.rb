require 'net/http'

class VowlController < ApplicationController
  include ActionController::Live

  def data
    uri = URI.parse("#{$REST_URL.to_s.chomp('/')}/ontologies/#{params[:acronym]}/vowl/data/ontology.json")
    uri.query = URI.encode_www_form(apikey: get_apikey)

    request_api = Net::HTTP::Get.new(uri)
    since = request.headers['If-Modified-Since']
    request_api['If-Modified-Since'] = since if since.present?

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme.eql?('https')) do |http|
      http.request(request_api) do |api_response|
        response.cache_control.merge!(no_cache: true, extras: ['private'])

        case api_response
        when Net::HTTPNotModified
          response.status = 304
        when Net::HTTPSuccess
          response.status = 200
          response.headers['Content-Type'] = 'application/json'
          response.headers['Last-Modified'] = api_response['Last-Modified'] if api_response['Last-Modified']
          api_response.read_body { |chunk| response.stream.write(chunk) }
        else
          response.status = 404
          response.headers['Content-Type'] = 'text/plain'
          response.stream.write('Visualization not available')
        end
      end
    end
  ensure
    response.stream.close
  end
end
