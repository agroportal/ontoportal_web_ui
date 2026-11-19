# frozen_string_literal: true

class PageHeaderComponent < ViewComponent::Base  
    def initialize(title: , description:)
      super()
      @title = title
      @description = description
    end  
end
  