class ViewDecorator
  attr_reader :view, :view_context

  def initialize(view, view_context)
    @view, @view_context = view, view_context
  end

  def linked_name
    view_context.link_to("<strong>#{view.name.to_s.upcase_first}</strong> <small>(#{view.acronym})</small>".html_safe, view_context.ontology_path(view.acronym))
  end

  def description
    latest_submission = view.explore.latest_submission
    latest_submission.nil? ? "No description provided" : latest_submission.description
  end
end