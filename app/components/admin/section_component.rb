# frozen_string_literal: true

# One block of the administration console: a titled card whose description is
# reachable from the info tooltip next to the title, and a body holding the
# actions of that block.
class Admin::SectionComponent < ViewComponent::Base

  def initialize(title:, description: nil, id: nil)
    super
    @title = title
    @description = description
    @id = id
  end

end
