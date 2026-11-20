# frozen_string_literal: true

class NotificationComponent < ViewComponent::Base

  def initialize(title:, comment: '', type: 'success', auto_remove: true)
    super()
    @title = title
    @comment = comment
    @type = type
    @auto_remove = auto_remove
  end

  def auto_remove?
    @auto_remove
  end

  def notification_type_icon
    svg_icon(@type)
  end

  def notification_animation_class
    auto_remove? ? 'slide-in-out-right' : 'slide-in-right'
  end

  def notification_type_class
    "type-#{@type}"
  end

  def notification_class
    notification_animation_class
  end

  private
  def svg_icon(name)
    inline_svg_tag("icons/#{name}.svg", class: notification_type_class)
  end


end
