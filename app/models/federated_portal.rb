# frozen_string_literal: true

class FederatedPortal < ApplicationRecord
  CACHE_KEY = 'federated_portals'
  CACHE_TTL = 12.hours

  validates :portal_key, presence: true, uniqueness: true
  validates :name, presence: true

  class << self
    def as_config
      order(:portal_key).each_with_object({}) do |portal, config|
        attributes = portal.to_config
        config[portal.portal_key.to_sym] = attributes if attributes
      end
    rescue StandardError => e
      Rails.logger.error("Error reading federated portals from the database: #{e.message}")
      {}
    end

    def sync!(portals)
      portals = portals.presence || {}

      transaction do
        portals.each { |key, attributes| upsert_portal(key, attributes) }

        stale = portals.any? ? where.not(portal_key: portals.keys.map(&:to_s)) : all
        stale.delete_all
      end

      true
    rescue StandardError => e
      Rails.logger.error("Error storing federated portals in the database: #{e.message}")
      false
    end

    def encryptor
      @encryptor ||= ActiveSupport::MessageEncryptor.new(
        Rails.application.key_generator.generate_key('FederatedPortal apikey',
                                                     ActiveSupport::MessageEncryptor.key_len)
      )
    end

    private

    def upsert_portal(key, attributes)
      portal = find_or_initialize_by(portal_key: key.to_s)
      portal.assign_attributes(
        name: attributes[:name].presence || key.to_s,
        ui: attributes[:ui],
        api: attributes[:api],
        color: attributes[:color],
        light_color: attributes[:'light-color'],
        apikey: attributes[:apikey]
      )
      portal.save!
    end
  end

  def apikey
    return nil if encrypted_apikey.blank?

    self.class.encryptor.decrypt_and_verify(encrypted_apikey)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    Rails.logger.warn("Could not decrypt the stored apikey of the federated portal #{portal_key}")
    nil
  end

  def apikey=(value)
    self.encrypted_apikey = value.presence && self.class.encryptor.encrypt_and_sign(value.to_s)
  end

  def to_config
    key = apikey
    return nil if key.blank?

    {
      name: name,
      ui: ui,
      api: api,
      color: color,
      apikey: key,
      'light-color': light_color
    }.compact
  end
end
