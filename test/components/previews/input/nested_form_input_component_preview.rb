class Input::NestedFormInputComponentPreview < ViewComponent::Preview

  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::FormTagHelper

  # @param object_name text
  def default(object_name: 'contact')
    render NestedFormInputsComponent.new(object_name: object_name) do |c|
      c.with_header do
        content_tag(:div, 'Contact name', class: 'w-50 mx-1') + content_tag(:div, 'Contact email', class: 'w-50 mx-1')
      end

      c.with_template do
        raw "<div class='d-flex'> <input class='form-control w-50 mx-1'/> <input class='form-control w-50 mx-1'/></div>".html_safe
      end
    end
  end
end