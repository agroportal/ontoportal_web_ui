# ViewComponent 4 no longer inherits ActionView::Base, so components lose
# the helpers gems mix into it. Give back the ones our components call.
ActiveSupport.on_load(:view_component) do
  include InlineSvg::ActionView::Helpers
  include FlagIconsRails::Rails::ViewHelpers
end
