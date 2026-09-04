# frozen_string_literal: true

require "rails_helper"

RSpec.describe DefinitionsComponent, type: :component do
  def render_component(definitions, **opts)
    render_inline(described_class.new(definitions: definitions, **opts))
  end

  it "renders nothing when there are no definitions" do
    expect(render_component(nil).to_html).to be_blank
    expect(render_component([]).to_html).to be_blank
    expect(render_component("").to_html).to be_blank
  end

  it "renders a single string definition as one paragraph" do
    result = render_component("A parasitic disease caused by Plasmodium.")

    texts = result.css(".definition-text")
    expect(texts.size).to eq(1)
    expect(texts.first.text).to include("A parasitic disease caused by Plasmodium.")
  end

  it "renders each definition of an array as its own list item" do
    result = render_component(["First definition.", "Second definition."])

    expect(result.css(".definitions-list > li").size).to eq(2)
    expect(result.css(".definition-text").map(&:text).map(&:strip))
      .to eq(["First definition.", "Second definition."])
  end

  it "sets neither italic nor the portal colour on the definition text" do
    result = render_component("A parasitic disease.")

    html = result.to_html
    expect(html).not_to include("font-style: italic")
    expect(html).not_to include("var(--primary-color)")
    expect(html).not_to include("var(--light-color)")
  end

  it "tags each definition with its language for the multilingual (hash) shape" do
    result = render_component({ en: ["A parasitic disease."], fr: ["Une maladie parasitaire."] })

    langs = result.css(".definition-lang").map { |n| n.text.strip }
    expect(langs).to contain_exactly("EN", "FR")

    french = result.css('.definition-text[lang="fr"]').first
    expect(french.text).to include("Une maladie parasitaire.")
  end

  it "hides the language badge from screen readers, which read the lang attribute instead" do
    result = render_component({ fr: ["Une maladie parasitaire."] })

    expect(result.css(".definition-lang").first["aria-hidden"]).to eq("true")
  end

  it "flattens several definitions sharing the same language" do
    result = render_component({ en: ["First definition.", "Second definition."] })

    expect(result.css(".definition-text").size).to eq(2)
  end

  it "does not show a language badge for language-agnostic definitions" do
    result = render_component({ "@none" => ["A parasitic disease."], "none" => ["Another one."] })

    expect(result.css(".definition-text").size).to eq(2)
    expect(result.css(".definition-lang")).to be_empty
  end

  it "normalizes an OpenStruct of languages (as returned by the API client)" do
    result = render_component(OpenStruct.new(en: ["A parasitic disease."], links: nil, context: nil))

    expect(result.css(".definition-text").size).to eq(1)
    expect(result.css(".definition-lang").first.text.strip).to eq("EN")
  end

  it "exposes the list as a list to assistive technology" do
    result = render_component(["First definition.", "Second definition."])

    expect(result.css("ul.definitions-list").first["role"]).to eq("list")
  end

  # Some vocabularies write a paragraph where others write a sentence, and six
  # paragraphs under "all languages" bury everything below them.
  describe "a definition too long for the row" do
    let(:long) { "The outputs of fisheries and aquaculture production, whole or in parts. " * 5 }

    it "is cropped, and read on through the app's own read-more control" do
      result = render_component([long])

      expect(result.css("[data-controller~='text-truncate']")).not_to be_empty
      expect(result.css(".text-content").first.text).to include("The outputs of fisheries")
    end

    it "is cropped to three lines" do
      result = render_component([long])

      expect(result.css("[data-controller~='text-truncate']").first["style"])
        .to include("--read-more-line-clamp: 3")
    end

    it "leaves a definition that fits whole" do
      result = render_component(["A parasitic disease caused by Plasmodium."])

      expect(result.css("[data-controller~='text-truncate']")).to be_empty
      expect(result.css(".definition-text").first.text.strip).to eq("A parasitic disease caused by Plasmodium.")
    end

    # Cropping hides everything past the third line, so the way through to the
    # node has to sit outside what is cropped.
    it "keeps the raw-data link out of what is cropped" do
      allow(ResourceLookupService).to receive(:values).and_return([{ text: long, lang: "en" }])
      node = "http://opendata.inrae.fr/thesaurusINRAE/note_101800en"
      result = render_component([node, long], acronym: "INRAETHES",
                                              parent_uri: "http://opendata.inrae.fr/thesaurusINRAE/c_10180",
                                              lang: "en")

      expect(result.css(".definition-text a.definition-raw-data").size).to eq(1)
      expect(result.css(".text-content a.definition-raw-data")).to be_empty
    end
  end

  # A reified definition arrives as the URI of the node holding the text. Set as
  # prose it reads as a sentence that happens to be a URL, which is what these
  # guard against.
  describe "a definition that is a URI, with no ontology to resolve it against" do
    let(:node) { "http://aims.fao.org/aos/agrovoc/xDef_46a719b8" }

    it "is never rendered as prose" do
      result = render_component([node])

      expect(result.css(".definition-text")).to be_empty
      expect(result.css(".definition-node")).not_to be_empty
    end

    it "is shown as the identifier it is" do
      uri = render_component([node]).css("span.definition-uri").first

      expect(uri).to be_present
      expect(uri.text.strip).to eq(node)
    end

    it "is not clickable, and opens nothing" do
      result = render_component([node])

      expect(result.css("a")).to be_empty
      expect(result.css("[data-controller~='show-modal']")).to be_empty
      expect(result.css("turbo-frame")).to be_empty
    end

    it "is never looked up" do
      expect(ResourceLookupService).not_to receive(:values)

      render_component([node])
    end

    it "still renders a literal definition beside it as prose" do
      result = render_component([node, "A parasitic disease."])

      expect(result.css(".definition-node").size).to eq(1)
      expect(result.css(".definition-text").map(&:text).map(&:strip)).to eq(["A parasitic disease."])
    end

    it "keeps the language badge on a URI definition" do
      result = render_component({ en: [node] })

      expect(result.css(".definition-node .definition-lang").first.text.strip).to eq("EN")
    end
  end

  # Given the ontology, the node is resolved and folded back into the prose:
  # what it holds is the definition, and the URI is only the address of it.
  describe "a definition that is a reified node" do
    let(:concept) { "http://opendata.inrae.fr/thesaurusINRAE/c_10180" }
    let(:english) { "http://opendata.inrae.fr/thesaurusINRAE/note_101800en" }
    let(:french)  { "http://opendata.inrae.fr/thesaurusINRAE/note_f8b3787c" }
    let(:text)    { "The action of reducing to smaller fragments by pressure or impact." }

    # Answers are given as plain strings; the service hands back { text:, lang: }.
    # No keyword here: a bare hash at the call site would be read as one.
    def resolving(answers)
      allow(ResourceLookupService).to receive(:values) do |_acronym, uri, **|
        answers.fetch(uri)&.map { |value| { text: value, lang: "en" } }
      end
    end

    def render_definitions(definitions)
      render_component(definitions, acronym: "INRAETHES", parent_uri: concept, lang: "en")
    end

    it "drops the URI of a node whose text was already extracted" do
      resolving(english => [text])
      result = render_definitions([english, text])

      expect(result.css(".definition-uri")).to be_empty
      expect(result.css(".definition-text").map(&:text).map(&:strip)).to eq([text])
    end

    it "opens that node's raw data from the text it was extracted into" do
      resolving(english => [text])
      link = render_definitions([english, text]).css("a.definition-raw-data").first

      expect(link).to be_present
      expect(link["href"]).to eq("/ontologies/INRAETHES/instances/show?instanceid=#{CGI.escape(english)}&modal=true")
      expect(link["data-controller"]).to include("show-modal")
    end

    it "matches a text the parser wrote with different spacing" do
      resolving(english => ["  The action of reducing to smaller\n fragments by pressure or impact.  "])
      result = render_definitions([english, text])

      expect(result.css(".definition-text").size).to eq(1)
      expect(result.css("a.definition-raw-data").size).to eq(1)
    end

    # Submissions parsed before the text was extracted hold nothing but nodes,
    # and the node's text is a better definition than the node's address.
    it "shows the node's text when there is no literal to fold it into" do
      resolving(english => [text])
      result = render_definitions([english])

      expect(result.css(".definition-uri")).to be_empty
      expect(result.css(".definition-text").first.text.strip).to start_with(text)
      expect(result.css("a.definition-raw-data").size).to eq(1)
    end

    # It is a definition, but not one in the language being read: the "all
    # languages" view is where it belongs.
    it "drops a node holding no text in this language" do
      resolving(english => [text], french => [])
      result = render_definitions([english, french, text])

      expect(result.css(".definition-uri")).to be_empty
      expect(result.css(".definition-text").map(&:text).map(&:strip)).to eq([text])
      expect(result.css("a.definition-raw-data").size).to eq(1)
    end

    # Under "all languages" there is no other language for it to be left to, so
    # a node that reads as nothing is a node nothing could read - and hiding it
    # would leave the row emptier than the resource is.
    it "keeps a node holding no text when every language was asked for" do
      allow(ResourceLookupService).to receive(:values).and_return([])
      result = render_component([english], acronym: "INRAETHES", parent_uri: concept, lang: "all")

      expect(result.css(".definition-uri").first.text.strip).to eq(english)
    end

    it "still drops it when one language was asked for" do
      allow(ResourceLookupService).to receive(:values).and_return([])
      result = render_component([english, text], acronym: "INRAETHES", parent_uri: concept, lang: "en")

      expect(result.css(".definition-uri")).to be_empty
      expect(result.css(".definition-text").map(&:text).map(&:strip)).to eq([text])
    end

    # A node carries no language of its own, so the tag comes from the literal
    # read out of it - which only SPARQL returns tagged.
    it "badges the node's own language when every language was asked for" do
      allow(ResourceLookupService).to receive(:values)
        .and_return([{ text: "Bir projede zaman ve özkaynak tüketen…", lang: "tr" }])
      result = render_component([english], acronym: "INRAETHES", parent_uri: concept, lang: "all")

      expect(result.css(".definition-lang").first.text.strip).to eq("TR")
      expect(result.css('.definition-text[lang="tr"]')).not_to be_empty
    end

    # Under one language the whole row is in it, and the app names it nowhere.
    it "badges nothing when one language was asked for" do
      resolving(english => [text])
      result = render_component([english], acronym: "INRAETHES", parent_uri: concept, lang: "en")

      expect(result.css(".definition-text").first.text.strip).to eq(text)
      expect(result.css(".definition-lang")).to be_empty
    end

    it "keeps the identifier of a node no source knows, inert" do
      resolving(english => nil)
      result = render_definitions([english, text])

      expect(result.css(".definition-uri").first.text.strip).to eq(english)
      expect(result.css("a")).to be_empty
    end

    # A definition pointing at a term of another vocabulary, or a plain URL
    # typed into the field: no node of this ontology, and no lookup to make.
    it "never looks up a URI minted by another vocabulary" do
      expect(ResourceLookupService).not_to receive(:values)
      result = render_definitions(["http://www.wkc.org.au/"])

      expect(result.css(".definition-uri").first.text.strip).to eq("http://www.wkc.org.au/")
    end

    it "does not show the same text twice when two nodes carry it" do
      resolving(english => [text], french => [text])
      result = render_definitions([english, french, text])

      expect(result.css(".definition-text").size).to eq(1)
    end

    it "leaves a definition with no node behind it unadorned" do
      result = render_definitions([text])

      expect(result.css("a.definition-raw-data")).to be_empty
    end
  end

  # A page of results reads a hundred and fifty resources at once, and wants of
  # each only the sentence. Which node a sentence came from is a click away on
  # the resource's own page, so a node the row already reads is dropped where it
  # stands rather than resolved.
  describe "a reified node under the summary lookup" do
    let(:concept) { "http://opendata.inrae.fr/thesaurusINRAE/c_10180" }
    let(:node)    { "http://opendata.inrae.fr/thesaurusINRAE/note_101800en" }
    let(:text)    { "The action of reducing to smaller fragments by pressure or impact." }

    def render_summary(definitions, **opts)
      render_component(definitions, acronym: "INRAETHES", parent_uri: concept, lang: "en",
                                    lookup: DefinitionsComponent::LOOKUP_SUMMARY, **opts)
    end

    it "drops the URI of a node beside a definition already written out" do
      result = render_summary([node, text])

      expect(result.css(".definition-uri")).to be_empty
      expect(result.css(".definition-text").map(&:text).map(&:strip)).to eq([text])
    end

    it "does so without a lookup" do
      expect(ResourceLookupService).not_to receive(:values)

      render_summary([node, text])
    end

    # Nothing else in the row: the node's text is the only definition there is,
    # and worth the one request it takes to read it.
    it "resolves a node that would otherwise leave the row empty" do
      allow(ResourceLookupService).to receive(:values).and_return([{ text: text, lang: "en" }])
      result = render_summary([node])

      expect(result.css(".definition-uri")).to be_empty
      expect(result.css(".definition-text").first.text.strip).to eq(text)
    end

    # A URI is not a sentence whichever ontology it came from, and dropping one
    # the row already reads needs no ontology to resolve it against.
    it "drops a redundant URI with no ontology to resolve it against" do
      result = render_component([node, text], lookup: DefinitionsComponent::LOOKUP_SUMMARY)

      expect(result.css(".definition-uri")).to be_empty
      expect(result.css(".definition-text").map(&:text).map(&:strip)).to eq([text])
    end

    it "keeps the identifier of a node that is all the row has" do
      allow(ResourceLookupService).to receive(:values).and_return(nil)

      expect(render_summary([node]).css(".definition-uri").first.text.strip).to eq(node)
    end
  end
end
