require "application_system_test_case"
require 'webmock/minitest'

class AnnotatorPageTest < ApplicationSystemTestCase
    # An annotation page takes ~2 s server side, longer than Capybara's
    # default wait, and the click that submits it returns right away
    ANNOTATION_WAIT_S = 10

    def setup
        WebMock.disable!
        @apikey = LinkedData::Client.settings.apikey
        @annotator_api = $ANNOTATOR_URL
        @host = "#{@annotator_api.split('/')[-2]}:443"
        @annotator_text_area = ".annotator-page-text-area > textarea"
        @sample_response = fixtures(:annotator)["sample_response"]
    end

    def teardown
        WebMock.disable!
    end

    test "go to annotator page and check if all the inputs and filters are there" do
        visit root_url
        click_link(href: '/annotator')
        assert_selector @annotator_text_area
        assert_selector 'div.insert-sample-text-button'
        # Check if there are the annotator's options
        assert_selector 'label[for="chips-whole_word_only-check"]'
        assert_selector 'label[for="chips-longest_only-check"]'
        assert_selector 'label[for="chips-expand_mappings-check"]'
        assert_selector 'label[for="chips-exclude_numbers-check"]'
        assert_selector 'label[for="chips-exclude_synonyms-check"]'
        assert_selector 'div.select-ontologies'

        # Open the advanced options
        find('div.advanced-options-button').click

        # Check if there are the advanced options
        assert_selector 'input#select_umls_semantic_types-ts-control', visible: :all
        assert_selector 'input#select_umls_semantic_groups-ts-control', visible: :all
        assert_selector 'input#select_ancestors_level-ts-control', visible: :all
        assert_selector 'input#select_include_score-ts-control', visible: :all
        assert_selector 'input[name="score_threshold"]'
        assert_selector 'input[name="confidence_threshold"]'
        assert_selector 'label[for="chips-fast_context-check"]'
        assert_selector 'label[for="chips-lemmatize-check"]'
    end

    test "go to annotator page insert sample text and get annotations" do
        visit root_url
        click_link(href: '/annotator')

        # Fill the annotator's text area input by a sample text
        find(@annotator_text_area).fill_in(with: 'Melanoma is a malignant tumor of melanocytes found mainly')

        # Mock the api call for the annotator with the entered text
        WebMock.enable!
        stub_request(:get, "#{@annotator_api}?class_hierarchy_max_level=None&confidence_threshold=0&score_threshold=0&text=Melanoma%20is%20a%20malignant%20tumor%20of%20melanocytes%20found%20mainly&whole_word_only=true")
            .with(
                headers: {
                        'Accept'=>'application/json',
                        'Authorization'=>"apikey token=#{@apikey}",
                        'Host'=> @host,
                        'User-Agent'=>'NCBO API Ruby Client v0.1.0'
                })
            .to_return(status: 200, body: @sample_response.to_json, headers: {})
        
        
        find(".annotator-page-button #annotator").click

        # Check if we get the table of annotations
        assert_selector 'table#annotator-table', wait: ANNOTATION_WAIT_S

        # Check if the number of annotations is 4
        assert_equal 5, page.all('tr').count
       
        # Check if we got the correct annotations
        assert_selector 'a[href="ontologies/AGROVOC/classes/http%3A%2F%2Faims.fao.org%2Faos%2Fagrovoc%2Fc_4713"]', text: 'Melanom'
        assert_selector 'a[href="ontologies/EUROSCIVOC/classes/http%3A%2F%2Fdata.europa.eu%2F8mn%2Feuroscivoc%2F276b8c99-a318-48df-aa31-1f9f3e0ba910"]', text: 'Melanom'
        assert_selector 'a[href="ontologies/INRAETHES/classes/http%3A%2F%2Fopendata.inrae.fr%2FthesaurusINRAE%2Fc_11970"]', text: 'mélanome'
        assert_selector 'a[href="ontologies/INRAETHES/classes/http%3A%2F%2Fopendata.inrae.fr%2FthesaurusINRAE%2Fc_11887"]', text: 'tumeur'

        # Check if the action buttons below the table are there (json, rdf, cite us and api doc buttons)
        assert_selector '#annotator_json'
        assert_selector '#annotator_rdf'
        assert_selector '#annotator_cite_us'
        assert_selector '#annotator_api_doc'
        
        # Clear the sample text in the annotator text area
        find(@annotator_text_area).native.clear

        # Fill it with a text that will return an empty state
        find(@annotator_text_area).fill_in(with: 'mainly')

        # Mock the api call of the annotator to get and return an empty result
        stub_request(:get, "#{@annotator_api}?class_hierarchy_max_level=None&confidence_threshold=0&score_threshold=0&text=mainly&whole_word_only=true")
            .with(
                headers: {
                        'Accept'=>'application/json',
                        'Authorization'=>"apikey token=#{@apikey}",
                        'Host'=> @host,
                        'User-Agent'=>'NCBO API Ruby Client v0.1.0'
                })
            .to_return(status: 200, body: ([]).to_json, headers: {})

        find(".annotator-page-button #annotator").click
        
        # Check if we got the empty state correctly
        assert_selector 'div.browse-empty-illustration', wait: ANNOTATION_WAIT_S
    end

end