# frozen_string_literal: true

require 'test_helper'

# The homepage advertises the OntoPortal instances published on ontoportal.org.
# Retired instances stay in that source for history, but must not be advertised.
class HomeControllerTest < ActiveSupport::TestCase
  PRODUCTION_PORTAL = { 'acronym' => 'AgroPortal', '@id' => 'https://agroportal.lirmm.fr/', 'status' => 'production' }.freeze
  RETIRED_PORTAL = { 'acronym' => 'SIFRBioPortal', '@id' => 'https://bioportal.lirmm.fr/', 'status' => 'retired' }.freeze

  # Answer the registry lookup itself so the test never reaches the network.
  def build_controller(portals)
    controller = HomeController.new
    controller.define_singleton_method(:ontoportal_instances) do
      send(:transform_portals_data, portals)
    end
    controller
  end

  test 'advertises the instances that are still running' do
    controller = build_controller([PRODUCTION_PORTAL, RETIRED_PORTAL])

    names = controller.send(:active_ontoportal_instances).map { |portal| portal[:name] }
    assert_equal ['AgroPortal'], names
  end

  test 'keeps retired instances in the full list' do
    controller = build_controller([PRODUCTION_PORTAL, RETIRED_PORTAL])

    names = controller.send(:ontoportal_instances).map { |portal| portal[:name] }
    assert_equal %w[AgroPortal SIFRBioPortal], names
  end
end
