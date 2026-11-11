# frozen_string_literal: true

class Layout::ProgressPagesComponentPreview < ViewComponent::Preview

  # @param pages_count number
  def default(pages_count: 5)
    render Layout::ProgressPagesComponent.new(pages_title: (pages_count || 0).times.map { |x| "page #{x}" }) do |c|
      5.times.each { |i| c.with_page { content_tag(:div, "page #{i}", class: "p-5 mx-5 text-center", style: 'width: 500px') } }
    end
  end
end
