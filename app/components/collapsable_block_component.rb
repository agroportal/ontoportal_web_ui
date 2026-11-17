# frozen_string_literal: true

class CollapsableBlockComponent < ViewComponent::Base
  renders_one :header


  def initialize(id: '', parent_id: '', collapsed: true, title: '')
    super()
    @id = id
    @collapsed = collapsed
    @parent_id = parent_id
    @title = title
  end

  def collapsed?
    @collapsed
  end

  def collapsed_class
    collapsed? ?  'collapsed' : 'show'
  end
end
