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
end
