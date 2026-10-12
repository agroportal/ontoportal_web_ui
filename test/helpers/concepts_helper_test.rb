# frozen_string_literal: true

require 'test_helper'

class ConceptsHelperTest < ActionView::TestCase
  include ConceptsHelper

  test 'the Graph tab follows the ENTITY_GRAPH flag' do
    Flipper.disable(ENTITY_GRAPH_FEATURE)
    refute entity_graph_enabled?

    Flipper.enable(ENTITY_GRAPH_FEATURE)
    assert entity_graph_enabled?
  end

  # A double-clicked graph node reloads the page on the clicked class
  test 'a graph node link opens the class on its Graph tab' do
    refute entity_graph_view?

    params[:view] = ENTITY_GRAPH_VIEW
    assert entity_graph_view?

    Flipper.disable(ENTITY_GRAPH_FEATURE)
    refute entity_graph_view?
  end

  test 'graph node links keep the page language' do
    assert_equal '/ontologies/PO?p=classes&view=concept-graph&language=FR', entity_graph_class_url('PO', 'FR')
  end
end
