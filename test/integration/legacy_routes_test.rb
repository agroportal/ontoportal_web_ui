require 'test_helper'

# Paths the app links to by literal URL that only the
# /:controller(/:action(/:id)) catch-all served until Rails 7.2 removed it
class LegacyRoutesTest < ActionDispatch::IntegrationTest
  test 'linked pages keep their routes without the catch-all' do
    assert_recognizes({ controller: 'my_ontologies', action: 'index' }, '/my-ontologies')
    assert_recognizes({ controller: 'statistics', action: 'index' }, '/statistics')
    assert_recognizes({ controller: 'landscape', action: 'index' }, '/landscape')
    assert_recognizes({ controller: 'content_finder', action: 'index' }, '/content_finder')
    assert_recognizes({ controller: 'admin', action: 'metadata_administration' }, '/admin/metadata_administration')
    assert_recognizes({ controller: 'search', action: 'json_search', id: 'STY' }, '/search/json_search/STY')
  end
end
