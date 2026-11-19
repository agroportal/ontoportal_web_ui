# frozen_string_literal: true
class Buttons::RegularButtonComponentPreview < ViewComponent::Preview
  include InlineSvg::ActionView::Helpers
  layout 'component_preview_not_centred'

  def primary
    render Buttons::RegularButtonComponent.new(id:'regular-button', value: "Login", variant: "primary")

  end

  def link
    render Buttons::RegularButtonComponent.new(id:'regular-button', value: "Link", variant: "primary", href: "#")
  end


  def secondary
    render Buttons::RegularButtonComponent.new(id:'regular-button', value: "Login", variant: "secondary")
  end

  def slim
    render Buttons::RegularButtonComponent.new(id:'regular-button', value: "Login", variant: "primary", size: "slim")
  end

  def danger
    render Buttons::RegularButtonComponent.new(id:'regular-button', value: "Login", variant: "primary", color: "danger")
  end

  def warning
    render Buttons::RegularButtonComponent.new(id:'regular-button', value: "Login", variant: "primary", color: "warning")
  end

  def disabled
    render Buttons::RegularButtonComponent.new(id:'regular-button', value: "Login", variant: "primary", state: "disabled")
  end

  def no_animation
    render Buttons::RegularButtonComponent.new(id:'regular-button', value: "Login", variant: "primary", state: "regular")
  end

  def icon_left
    render Buttons::RegularButtonComponent.new(id:'regular-button', value: "Login", variant: "primary") do |btn|
      btn.with_icon_left do
        inline_svg_tag "check.svg"
      end
    end
  end

  def icon_right

    render Buttons::RegularButtonComponent.new(id:'regular-button', value: "Login", variant: "primary") do |btn|
      btn.with_icon_right do
        inline_svg_tag "check.svg"
      end
    end
  end

end