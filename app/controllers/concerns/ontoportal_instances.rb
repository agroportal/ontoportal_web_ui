# frozen_string_literal: true

require 'net/http'
require 'json'
require 'ipaddr'

# Reads the OntoPortal instances published on https://ontoportal.org/portals.json.
# That list describes the portals but never says where their APIs live, so every
# instance is asked directly through its own /site_config endpoint.
module OntoportalInstances
  extend ActiveSupport::Concern

  PORTALS_SOURCE_URL = 'https://ontoportal.org/portals.json'
  SITE_CONFIG_TIMEOUT = 5

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

  def fetch_ontoportal_instances
    uri = URI(PORTALS_SOURCE_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    return [] unless response.is_a?(Net::HTTPSuccess)

    with_portals_api_endpoints(transform_portals_data(JSON.parse(response.body)))
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
      api: portal['api'],
      color: portal['color'] || '#000000',
      apikey: portal['apikey'],
      federation: portal['federation'] == true,
      'light-color': portal['light-color']
    }
  end

  # Every OntoPortal UI publishes its own REST url on /site_config, so ask each
  # portal where its API lives instead of maintaining that list by hand.
  def with_portals_api_endpoints(portals)
    portals.map do |portal|
      Thread.new { portal[:api].present? ? portal : portal.merge(portal_site_config(portal[:ui])) }
    end.map(&:value)
  end

  def portal_site_config(ui, redirects: 3)
    uri = URI.join(ui, '/site_config')
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                                   open_timeout: SITE_CONFIG_TIMEOUT,
                                                   read_timeout: SITE_CONFIG_TIMEOUT) do |http|
      http.request(Net::HTTP::Get.new(uri.request_uri))
    end
    # Portals listed with an http url usually redirect to their https one
    if response.is_a?(Net::HTTPRedirection) && redirects.positive?
      return portal_site_config(response['location'], redirects: redirects - 1)
    end
    return {} unless response.is_a?(Net::HTTPSuccess)

    site_config = JSON.parse(response.body)
    return {} unless reachable_url?(site_config['rest_url'])

    { api: site_config['rest_url'] }
  rescue StandardError => e
    Rails.logger.info("Could not read the site configuration of #{ui}: #{e.message}")
    {}
  end

  # An appliance can advertise an address that is only reachable on its own network,
  # which would make every page render wait for a connection timeout.
  def reachable_url?(url)
    host = URI.parse(url.to_s).host
    return false if host.blank?

    address = IPAddr.new(host)
    !(address.private? || address.loopback?)
  rescue IPAddr::InvalidAddressError
    true # a regular host name, not an IP address
  rescue StandardError
    false
  end

  # Portals shielded from automated requests never answer /site_config, so complete
  # the list with the endpoints of the portals we are already federated with.
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
