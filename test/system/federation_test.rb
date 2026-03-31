require "application_system_test_case"

class FederationTest < ApplicationSystemTestCase

  setup do
    @search_path = "/search"
    @query = "test"
    @ontologies_path = "/ontologies"
  end

  test "perform federated search in search page and make sure federation is working" do

    visit "#{@search_path}?q=#{@query}"
    results_count_no_federation = find('.search-page-number-of-results').text.scan(/\d+/).first.to_i

    visit "#{@search_path}?q=#{@query}&lang=all&portals%5B%5D=agroportal"
    results_count_federation = find('.search-page-number-of-results').text.scan(/\d+/).first.to_i

    assert_not_equal results_count_no_federation, results_count_federation

    results_titles = all("a.title div").map { |div| div.text.strip }

    assert_equal results_titles.count, results_titles.uniq.count, "There are duplicated results !"

  end


  test "perform federated browse and make sure federation is working" do
    ###### Federation non activated
    visit "#{@ontologies_path}"
    loop do # make sure page is not still loading
      loading_element = find_all(".browse-sket").any?
      break unless loading_element
      page.execute_script("window.scrollBy(0, window.innerHeight)")
      sleep 0.3
    end
    results_count_no_federation = first('.browse-desc-text').text.scan(/\d+/).first.to_i

    find("[data-target='#browse-categories-filter']").click
    loop do # make sure page is not still loading
      loading_element = find_all(".browse-sket").any?
      break unless loading_element
    end

    number_categories_no_federation = all("input", visible: :all).count


    ### Federation activated

    visit "#{@ontologies_path}?sort_by=ontology_name&portals=agroportal"


    loop do # Scroll all down to display all the results
      loading_element = find_all(".browse-sket").any?

      break unless loading_element

      page.execute_script("window.scrollBy(0, window.innerHeight)")

      sleep 0.3
    end

    results_count_federation = first('.browse-desc-text').text.scan(/\d+/).first.to_i

    assert_not_equal results_count_no_federation, results_count_federation

    ontologies_titles = all(".browse-ontology-title").map { |a| a.text.strip }

    assert_equal ontologies_titles.count, ontologies_titles.uniq.count, "There are duplicated results !"


    find("[data-target='#browse-categories-filter']").click

    loop do
      loading_element = find_all(".browse-sket").any?
      break unless loading_element
    end

    number_categories_federation = all("input", visible: :all).count

    assert_not_equal number_categories_no_federation, number_categories_federation

  end

  test 'federated_search_when_portal_down' do
    visit "#{@search_path}?q=#{@query}&lang=all&portals%5B%5D=testportal-down"
    assert_selector ".alert-warning-type", visible: true
  end

  test 'federated_browse_when_portal_down' do
    visit "#{@ontologies_path}?sort_by=ontology_name&portals=testportal-down"
    loop do
      loading_element = find_all(".browse-sket").any?

      break unless loading_element

      page.execute_script("window.scrollBy(0, window.innerHeight)")

      sleep 0.3
    end
    assert_selector ".alert-warning-type", visible: true
  end
end
