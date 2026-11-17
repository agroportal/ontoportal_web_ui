# frozen_string_literal: true

class RoleSelectorComponent < ViewComponent::Base

    def initialize(agentOntologies: nil)
      super()
      @agentOntologies = agentOntologies
    end
  end
  