# frozen_string_literal: true

require 'test_helper'

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test 'should show home page' do
    get ''
    assert_response :success
  end

  test 'should show projects page' do
    get '/projects'
    assert_response :success
  end

  test 'should show annotator page' do
    get '/annotator'
    assert_response :success
  end

  test 'should show recommender page' do
    get '/recommender'
    assert_response :success
  end

  test 'should show mapping page' do
    get '/mappings'
    assert_response :success
  end

  test 'should show feedback page' do
    get '/feedback'
    assert_response :success
  end

  # The navbar feedback link reports the current page. On /feedback itself it
  # must keep the reported page, not wrap its own URL: each click would nest
  # one more level (/feedback?location=/feedback?location=...), a crawler trap.
  test 'feedback page links feedback to the page already reported' do
    reported = CGI.escape('http://www.example.com/ontologies/ENVO')

    get '/feedback', params: { location: reported }

    link = css_select('#submitFeedbackMenuItem').first
    assert_equal "/feedback?location=#{CGI.escape(reported)}", link['href']
  end
end
