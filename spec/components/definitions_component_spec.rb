# frozen_string_literal: true

require "rails_helper"

RSpec.describe DefinitionsComponent, type: :component do
  def render_definitions(definitions, definition_nodes: nil)
    render_inline(described_class.new(definitions: definitions, definition_nodes: definition_nodes))
  end

  # A resolved reified node, as the API client returns it (an OpenStruct with an
  # @id plus value/source/created/modified).
  def node(attrs)
    OpenStruct.new(attrs)
  end

  it "does not render when there is no definition" do
    expect(render_definitions(nil).to_html).to be_blank
    expect(render_definitions([]).to_html).to be_blank
    expect(render_definitions([""]).to_html).to be_blank
  end

  it "drops a node that carries no value, source or URI" do
    expect(render_definitions([], definition_nodes: [node(value: nil)]).to_html).to be_blank
  end

  it "renders a simple definition as plain text, not as a link or badge" do
    result = render_definitions(["The science and practice of farming"])

    expect(result.css(".definition-text").text).to eq("The science and practice of farming")
    expect(result.css("a")).to be_empty
    expect(result.css(".definition-badge")).to be_empty
  end

  it "renders each definition of an array" do
    result = render_definitions(["First definition", "Second definition"])

    texts = result.css(".definition-text").map { |n| n.text.strip }
    expect(texts).to eq(["First definition", "Second definition"])
  end

  context "with a resolved reified node (definitionXl)" do
    let(:uri) { "http://opendata.inrae.fr/thesaurusINRAE/note_101800en" }
    let(:reified) do
      node(
        :"@id" => uri,
        :value => "The action of reducing to smaller fragments by pressure or impact.",
        :source => "Baize, D. (2016) Petit lexique de pédologie",
        :created => "2026-02-04T16:31:45.000+00:00"
      )
    end

    it "shows the resolved text, a Reified badge, the source and the date" do
      result = render_definitions([uri], definition_nodes: [reified])

      expect(result.css(".definition-text").text).to include("The action of reducing to smaller fragments")
      expect(result.css("a")).to be_empty
      expect(result.css(".definition-badge").text).to eq(I18n.t("ontology_details.concept.reified"))

      expect(result.css(".definition-meta").text).to include("Baize, D. (2016) Petit lexique de pédologie")

      time = result.css("time").first
      expect(time["datetime"]).to eq("2026-02-04T16:31:45.000+00:00")
      expect(time.text.strip).to be_present
    end

    it "does not duplicate a reified definition listed both flat and as a node" do
      result = render_definitions([uri], definition_nodes: [reified])

      expect(result.css(".definition-item").size).to eq(1)
      # the opaque node URI is never surfaced once we have the text
      expect(result.to_html).not_to include(uri)
    end
  end

  it "renders a node that carries only a source (no dates)" do
    n = node(:"@id" => "http://x/note_1", :value => "A definition", :source => "Some source")
    result = render_definitions(["http://x/note_1"], definition_nodes: [n])

    expect(result.css(".definition-text").text).to include("A definition")
    expect(result.css(".definition-meta").text).to include("Some source")
    expect(result.css("time")).to be_empty
  end

  it "labels a modification date" do
    n = node(:"@id" => "http://x/note_2", :value => "Def", :modified => "2026-03-05")
    result = render_definitions(["http://x/note_2"], definition_nodes: [n])

    expect(result.css("time").first["datetime"]).to eq("2026-03-05")
    expect(result.css(".definition-meta").text).to include(I18n.t("ontology_details.concept.definition_modified"))
  end

  it "keeps an unparseable date verbatim instead of dropping it" do
    n = node(:"@id" => "http://x/note_3", :value => "Def", :created => "unknown-date")
    result = render_definitions(["http://x/note_3"], definition_nodes: [n])

    expect(result.css("time").text).to include("unknown-date")
  end

  it "accepts a plain Hash node (string keys) as well as an object" do
    n = { "@id" => "http://x/note_4", "value" => "Hash def", "source" => "Hash source" }
    result = render_definitions(["http://x/note_4"], definition_nodes: [n])

    expect(result.css(".definition-text").text).to include("Hash def")
    expect(result.css(".definition-meta").text).to include("Hash source")
  end

  it "handles a mix of a simple definition and a reified node" do
    n = node(:"@id" => "http://x/note_5", :value => "Reified text", :source => "Src")
    result = render_definitions(["A plain definition", "http://x/note_5"], definition_nodes: [n])

    expect(result.css(".definition-item").size).to eq(2)
    expect(result.css(".definition-badge").size).to eq(1) # only the reified one
    expect(result.to_html).to include("A plain definition")
    expect(result.to_html).to include("Reified text")
  end

  it "falls back to a marked link for a reified URI the API did not resolve" do
    uri = "http://aims.fao.org/aos/agrovoc/xDef_4746fb52"
    result = render_definitions([uri]) # no definition_nodes

    expect(result.css(".definition-badge").text).to eq(I18n.t("ontology_details.concept.reified"))

    link = result.css("a.definition-reified-link").first
    expect(link).to be_present
    expect(link["href"]).to eq(uri)
    expect(link["target"]).to eq("_blank")
    expect(link["rel"]).to include("noopener")
    expect(link.text).to include("xDef_4746fb52")
  end

  it "keeps simple text with an embedded URL as plain text (only a bare IRI is reified)" do
    result = render_definitions(["See http://example.org for more"])

    expect(result.css(".definition-badge")).to be_empty
    expect(result.css("a")).to be_empty
    expect(result.css(".definition-text").text).to eq("See http://example.org for more")
  end

  it "flattens a language-keyed hash of definitions" do
    result = render_definitions({ "en" => ["English definition"], "fr" => ["Définition française"] })

    texts = result.css(".definition-text").map { |n| n.text.strip }
    expect(texts).to contain_exactly("English definition", "Définition française")
  end

  it "treats an object exposing #uri (no resolved node) as a reified link" do
    obj = OpenStruct.new(uri: "http://aims.fao.org/aos/agrovoc/xDef_7484cb96")
    result = render_definitions([obj])

    link = result.css("a.definition-reified-link").first
    expect(link["href"]).to eq("http://aims.fao.org/aos/agrovoc/xDef_7484cb96")
    expect(result.css(".definition-badge")).to be_present
  end

  context "language tags (all-languages mode)" do
    def lang_node(uri, value, lang)
      node(:"@id" => uri, :value => value, :lang => lang)
    end

    it "tags each definition with its language when they span multiple languages" do
      nodes = [lang_node("http://x/n_en", "The action of reducing…", "en"),
               lang_node("http://x/n_fr", "Action de réduire…", "fr")]
      result = render_definitions(["http://x/n_en", "http://x/n_fr"], definition_nodes: nodes)

      expect(result.css(".definition-lang").map { |t| t.text.strip }).to contain_exactly("EN", "FR")
    end

    it "does not tag definitions when they are all in the same language" do
      nodes = [lang_node("http://x/n1", "First English def", "en"),
               lang_node("http://x/n2", "Second English def", "en")]
      result = render_definitions(["http://x/n1", "http://x/n2"], definition_nodes: nodes)

      expect(result.css(".definition-lang")).to be_empty
    end

    it "does not tag a single definition" do
      result = render_definitions(["http://x/n1"], definition_nodes: [lang_node("http://x/n1", "Def", "en")])

      expect(result.css(".definition-lang")).to be_empty
    end
  end
end
