# frozen_string_literal: true

require "rails_helper"

RSpec.describe OntologyBrowseCardComponent, type: :component do
  # One of the portal's own ontologies, scored: its FAIR details open in a modal
  let(:ontology) do
    { id: "#{$REST_URL.chomp('/')}/ontologies/STY", acronym: "STY", name: "Semantic Types", private: false,
      ontology: { administeredBy: [] }, description: "Types of concepts.", format: "OWL",
      fairScore: 42.0, normalizedFairScore: 50, class_count_formatted: "133",
      individual_count_formatted: "0", project_count: 0, note_count: 0 }
  end

  # The modal link is built by a view helper, from inside the card's template:
  # the card comes out once, and the link holds its own text, nothing else.
  it "renders the FAIR details link around its text only" do
    card = render_inline(described_class.new(ontology: ontology))

    expect(card.css("a.browse-ontology-title").size).to eq(1)
    expect(card.css("a.browse-fair-details").text.strip).to eq(I18n.t("components.details_details"))
  end
end
