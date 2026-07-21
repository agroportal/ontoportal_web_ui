# frozen_string_literal: true

require "rails_helper"

RSpec.describe SynonymsComponent, type: :component do
  def render_component(synonyms, **opts)
    render_inline(described_class.new(synonyms: synonyms, **opts))
  end

  it "renders nothing when there are no synonyms" do
    expect(render_component(nil).to_html).to be_blank
    expect(render_component([]).to_html).to be_blank
    expect(render_component("").to_html).to be_blank
  end

  it "renders a single string synonym as one chip and no modal" do
    result = render_component("Etiology")

    chips = result.css(".synonym-chip")
    expect(chips.size).to eq(1)
    expect(chips.first.text).to include("Etiology")
    expect(result.css("dialog")).to be_empty
  end

  it "renders an array of synonyms as chips without a modal when under the limit" do
    result = render_component(%w[Cause Origin], show_max: 10)

    expect(result.css(".synonym-chip").size).to eq(2)
    expect(result.css(".synonym-chip--more")).to be_empty
    expect(result.css("dialog")).to be_empty
  end

  it "shows a '+N' chip and a modal listing every synonym when over the limit" do
    synonyms = (1..12).map { |i| "syn#{i}" }
    result = render_component(synonyms, show_max: 10)

    visible = result.css(".synonyms-list:not(.synonyms-list--modal) .synonym-chip")
    expect(visible.size).to eq(11) # 10 synonyms + the "more" chip

    more = result.css(".synonym-chip--more").first
    expect(more).to be_present
    expect(more.text).to include("+2")
    expect(more.name).to eq("button")

    dialog = result.css("dialog.synonyms-modal").first
    expect(dialog).to be_present
    expect(dialog.css(".synonyms-list--modal .synonym-chip").size).to eq(12)
  end

  it "tags each chip with its language for the multilingual (hash) shape" do
    result = render_component({ en: ["Etiology"], fr: ["Étiologie"] })

    langs = result.css(".synonym-chip__lang").map { |n| n.text.strip }
    expect(langs).to contain_exactly("EN", "FR")
    expect(result.css('.synonym-chip__text[lang="fr"]').first.text).to eq("Étiologie")
  end

  it "flattens several values sharing the same language" do
    result = render_component({ en: %w[Cause Origin] })

    expect(result.css(".synonym-chip").size).to eq(2)
  end

  it "does not show a language tag for language-agnostic values" do
    result = render_component({ "@none" => ["Etiology"], "none" => ["Cause"] })

    expect(result.css(".synonym-chip").size).to eq(2)
    expect(result.css(".synonym-chip__lang")).to be_empty
  end

  it "normalizes an OpenStruct of languages (as returned by the API client)" do
    result = render_component(OpenStruct.new(en: ["Etiology"], links: nil, context: nil))

    expect(result.css(".synonym-chip").size).to eq(1)
    expect(result.css(".synonym-chip__lang").first.text.strip).to eq("EN")
  end
end
