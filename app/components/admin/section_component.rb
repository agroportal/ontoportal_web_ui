# frozen_string_literal: true

class Admin::SectionComponent < ViewComponent::Base

  def initialize(title:, description: nil, id: nil)
    super
    @title = title
    @description = description
    @id = id
  end

end
