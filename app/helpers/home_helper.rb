require 'open-uri'
require 'nokogiri'

module HomeHelper

  def render_footer_link(options = {})
    link_content = options[:text][I18n.locale] || options[:text][:en] if options[:text]
    link_content ||= image_tag(options[:img_src]) if options[:img_src]
    link_content ||= content_tag(:i, '', class: options[:icon]) if options[:icon]

    link_to(link_content, options[:url], target: options[:target], class: options[:css_class].to_s, style: options[:text].blank? ? 'text-decoration: none' : '').html_safe if link_content
  end


  def format_number_abbreviated(number)
    number = 0 if number.nil?

    if number >= 1_000_000
      (number / 1_000_000).to_s + 'M'
    elsif number >= 1_000
      (number / 1_000).to_s + 'K'
    else
      number.to_s
    end
  end

  def portal_config_tooltip(portal, &block)
    return capture(&block) if portal.blank?

    portal = { name: portal } if portal.is_a?(String)
    portal_id = portal[:name].to_s.downcase
    return capture(&block) if portal_id.blank?

    title = if portal_config_readable?(portal_id, portal[:api])
      render(
        TurboFrameComponent.new(
          id: "portal_config_tooltip_#{portal_id}",
          src: "/config?portal=#{portal_id}",
          style: "width: 600px !important; max-height: 300px; overflow: scroll"
        )
      )
    end
    render Display::InfoTooltipComponent.new(text: title, interactive: true) do
      capture(&block)
    end
  end

  # Only offer the details popup for portals we can actually describe: this one, or a
  # portal exposing a reachable API.
  def portal_config_readable?(portal_id, api)
    return true if portal_id.eql?(portal_name&.downcase)

    api.present? && federation_portal_status(portal_name: portal_id.to_sym, api: api)
  end

  def discover_ontologies_button
    render Buttons::RegularButtonComponent.new(id: 'discover-ontologies-button', value: t('home.discover_ontologies_button'), variant: "secondary", state: "regular", href: "/ontologies") do |btn|
      btn.icon_right do
        inline_svg_tag "arrow-right.svg"
      end
    end
  end

  def home_ontoportal_description
    ontoportal_link = link_to("(#{$ONTOPORTAL_WEBSITE_LINK})", $ONTOPORTAL_WEBSITE_LINK, target: '_blank')
    github_link = link_to("(#{$ONTOPORTAL_GITHUB_REPO})", $ONTOPORTAL_GITHUB_REPO, target: '_blank')
    content_tag(:div, t('home.ontoportal_description', ontoportal_link: ontoportal_link, github_link: github_link).html_safe, style: "margin-bottom: 20px")
  end


end
