# frozen_string_literal: true

require "rails_helper"

RSpec.describe Display::SearchResultComponent, type: :component do
  let(:concept) { "http://aims.fao.org/aos/agrovoc/c_9000021" }
  let(:node)    { "http://aims.fao.org/aos/agrovoc/xDef_46a719b8" }
  let(:text)    { "Coastal areas are commonly defined as the interface between land and sea." }

  def render_result(definition, **opts)
    render_inline(described_class.new(title: "coastal areas - AGROVOC", uri: concept, definition: definition,
                                      ontology_id: "http://data.agroportal.eu/ontologies/AGROVOC",
                                      link: "/ontologies/AGROVOC", lang: "en", **opts))
  end

  it "renders a plain definition as prose" do
    result = render_result([text])

    expect(result.css(".definition-text").first.text.strip).to eq(text)
  end

  it "renders no definition row when the result has none" do
    expect(render_result(nil).css(".definitions-component")).to be_empty
  end

  # The search endpoint returns a reified definition the way every other
  # endpoint does: the URI of the node, beside the text extracted from it.
  describe "a definition that is a reified node" do
    it "is never set as prose" do
      result = render_result([text, node])

      expect(result.css(".definition-text").map(&:text).map(&:strip)).to eq([text])
      expect(result.css(".definition-uri")).to be_empty
    end

    # 150 results deep, the node says only which sentence came from where - and
    # that is a click away under "Details", not worth a request per result.
    it "costs no lookup when the row already carries its text" do
      expect(ResourceLookupService).not_to receive(:values)

      render_result([text, node])
    end

    # Nothing else to show: the node's text is the only definition there is, and
    # is worth the one request it takes to read it.
    it "is resolved when the row would otherwise be empty" do
      allow(ResourceLookupService).to receive(:values).and_return([{ text: text, lang: "en" }])
      result = render_result([node])

      expect(result.css(".definition-text").first.text.strip).to start_with(text)
      expect(result.css(".definition-uri")).to be_empty
    end

    # A class from another portal is no resource of ours, and our API 404s on it.
    it "is never looked up on a result from another portal" do
      expect(ResourceLookupService).not_to receive(:values)
      result = render_result([node], portal_name: "agroportal")

      expect(result.css(".definition-uri").first.text.strip).to eq(node)
    end
  end
end
