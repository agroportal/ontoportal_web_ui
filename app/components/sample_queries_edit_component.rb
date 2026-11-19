# frozen_string_literal: true
class SampleQueriesEditComponent < ViewComponent::Base
  include ModalHelper, ApplicationHelper
  def initialize(graph: nil)
    super()
    @graph = graph
  end
end