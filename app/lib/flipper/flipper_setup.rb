# app/lib/flipper_setup.rb
module FlipperSetup
  FEATURES = ["Agents", "SPARQL", "SIDEKIQ_UI", "FOOPS"].freeze
  # Listed in the Flipper UI but left off: an admin turns them on per portal
  OPT_IN_FEATURES = ["ENTITY_GRAPH"].freeze

  def self.configure!
    Flipper.configure do |config|
      config.default do
        primary_adapter = Flipper::Adapters::ActiveRecord.new 

        flipper = Flipper.new(Flipper::Adapters::ActiveSupportCacheStore.new(
            primary_adapter, 
            Rails.cache, 
            10.minutes
          )
        )
        # Seed features enabled by default, without overriding those already
        # configured by an admin in the Flipper UI
        existing_features = primary_adapter.features
        FEATURES.each { |f| flipper.enable(f) unless existing_features.include?(f) }
        OPT_IN_FEATURES.each { |f| flipper.add(f) }

        flipper
      end
      Flipper.register(:admins) do |actor, context|
        actor.respond_to?(:admin?) && actor.admin?
      end
    end
  end
  def self.test_configure!
    (FEATURES + OPT_IN_FEATURES).each { |feature| Flipper.enable(feature) }
  end
end