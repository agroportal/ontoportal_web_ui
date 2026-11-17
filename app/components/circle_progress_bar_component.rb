# frozen_string_literal: true

class CircleProgressBarComponent < ViewComponent::Base

  def initialize(count: , max: )
    super()
    @count = count
    @max = max
  end

  def value
    ((@count.to_f / @max) * 100).to_i
  end
end
