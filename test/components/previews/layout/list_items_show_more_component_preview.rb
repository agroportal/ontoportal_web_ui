class Layout::ListItemsShowMoreComponentPreview < ViewComponent::Preview

  def default
    render ListItemsShowMoreComponent.new(max_items: 5) do |component|
      10.times do |i|
        component.with_container do
          "Item #{i + 1}"
        end
      end
    end
  end

end
