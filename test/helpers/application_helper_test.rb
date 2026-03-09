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

  test "append_apikey_if_rest_url with a URL that has no query params" do
    user = OpenStruct.new(apikey: "user_api_key")
    rest_url = "http://api.example.com"
    LinkedData::Client.settings.rest_url = rest_url
    
    link = "http://api.example.com/ontologies/TEST/download"
    # This used to raise "undefined method `ascii_only?' for []:Array"
    result = append_apikey_if_rest_url(link, user)
    
    assert_includes result, "apikey=user_api_key"
  end

  test "append_apikey_if_rest_url with a URL that already has an apikey" do
    user = OpenStruct.new(apikey: "new_api_key")
    rest_url = "http://api.example.com"
    LinkedData::Client.settings.rest_url = rest_url
    
    link = "http://api.example.com/ontologies/TEST/download?apikey=old_api_key"
    result = append_apikey_if_rest_url(link, user)
    
    assert_includes result, "apikey=new_api_key"
    refute_includes result, "apikey=old_api_key"
  end

  test "append_apikey_if_rest_url with fairness URL" do
    user = OpenStruct.new(apikey: "user_api_key")
    $FAIRNESS_URL = "http://fairness.example.com"
    LinkedData::Client.settings.rest_url = "http://api.example.com"
    
    link = "http://fairness.example.com/evaluate"
    result = append_apikey_if_rest_url(link, user)
    
    assert_includes result, "apikey=user_api_key"
  end
end
