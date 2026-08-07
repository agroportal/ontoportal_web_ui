# frozen_string_literal: true

require 'net/http'
require 'json'

# Reads the OntoPortal instances published on https://ontoportal.org/portals.json,
# which describes every portal and where its API lives.
module OntoportalInstances
  extend ActiveSupport::Concern

  PORTALS_SOURCE_URL = 'https://ontoportal.org/portals.json'

  private

  def ontoportal_instances
    portals = Rails.cache.fetch('ontoportal_instances', expires_in: 24.hours) do
      fetch_ontoportal_instances
    end

    resolve_missing_portals_api(portals)
  end

  def federated_ontoportal_instances
    ontoportal_instances.select { |portal| portal[:federation] }
  end

  # Whether the current portal is registered as a *federated* portal on
  # ontoportal.org/portals.json (matched by the request host domain). Single source
  # of truth for both enabling federation in admin and showing the homepage
  # federation section.
  def current_portal_federated_on_source?(portals = federated_ontoportal_instances)
    domain = portal_domain(request.host)
    return false if domain.blank?

    portals.any? { |portal| federated_portal_domains(portal).include?(domain) }
  end

  # The domains a federated instance can be recognised by (its UI and API).
  def federated_portal_domains(portal)
    [portal_domain(portal[:ui]), portal_domain(portal[:api])].compact
  end

  def fetch_ontoportal_instances
    uri = URI(PORTALS_SOURCE_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    return [] unless response.is_a?(Net::HTTPSuccess)

    transform_portals_data(JSON.parse(response.body))
  rescue StandardError => e
    Rails.logger.error("Error fetching portals from ontoportal.org: #{e.message}")
    []
  end

  def transform_portals_data(data)
    # Transform the JSON-LD data to match the expected format
    portals = if data.is_a?(Hash) && data['@graph'].is_a?(Array)
                data['@graph']
              elsif data.is_a?(Array)
                data
              else
                []
              end

    portals.map { |portal| transform_portal_entry(portal) }
           .compact
           .select { |portal| portal[:name].present? && portal[:ui].present? }
  end

  def transform_portal_entry(portal)
    return nil unless portal.is_a?(Hash)

    # Map JSON-LD fields to expected format
    {
      name: portal['acronym'] || portal['name'],
      ui: portal['@id'] || portal['ui'],
      api: portal_api_url(portal),
      color: portal['color'] || '#000000',
      description: portal['description'],
      status: portal['status'],
      apikey: portal['apikey'],
      federation: portal['federation'] == true,
      'light-color': portal['light-color']
    }
  end

  # The registry types the API endpoint as a schema.org/WebAPI node, so the url sits
  # in its @id rather than on the property itself.
  def portal_api_url(portal)
    api_url = portal['api_url'] || portal['api']
    api_url.is_a?(Hash) ? api_url['@id'] || api_url['url'] : api_url
  end

  # A portal can be published without an API endpoint, so complete the list with the
  # endpoints of the portals we are already federated with.
  def resolve_missing_portals_api(portals)
    return portals if portals.all? { |portal| portal[:api].present? }

    known_portals = known_portals_by_domain
    portals.map do |portal|
      next portal if portal[:api].present?

      known_portal = known_portals[portal_domain(portal[:ui])]
      known_portal ? portal.merge(api: known_portal[:api]) : portal
    end
  end

  def known_portals_by_domain
    helpers.federated_portals.values.each_with_object({}) do |portal, by_domain|
      domain = portal_domain(portal[:ui])
      next if domain.blank? || portal[:api].blank?

      by_domain[domain] ||= portal
    end
  end

  # Extract and normalize the domain from a full URL
  # e.g., "https://agroportal.lirmm.fr/" -> "agroportal.lirmm.fr"
  def portal_domain(url)
    URI.parse(url.to_s).host&.downcase || url.to_s.downcase.presence
  rescue StandardError
    url.to_s.downcase.presence
  end
end
