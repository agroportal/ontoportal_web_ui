require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  setup do
    @original_rest_url = LinkedData::Client.settings.rest_url rescue nil
    @original_fairness_url = $FAIRNESS_URL rescue nil
  end

  teardown do
    LinkedData::Client.settings.rest_url = @original_rest_url if @original_rest_url
    $FAIRNESS_URL = @original_fairness_url
  end
end
