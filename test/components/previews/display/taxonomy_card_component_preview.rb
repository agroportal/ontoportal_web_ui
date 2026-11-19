require 'ostruct'

class Display::TaxonomyCardComponentPreview < ViewComponent::Preview

  def with_sub_categories
    children = %w[CROPS LIVESTOCK].map { |acronym| category(acronym, ontologies: %w[AGROVOC]) }
    render Display::TaxonomyCardComponent.new(taxonomy: category('AGRI', ontologies: %w[AGROVOC CROPONT], children: children),
                                              ontologies_names: ontologies_names)
  end

  def without_sub_categories
    render Display::TaxonomyCardComponent.new(taxonomy: category('FOOD', ontologies: %w[CROPONT]),
                                              ontologies_names: ontologies_names)
  end

  private

  def category(acronym, ontologies:, children: nil)
    OpenStruct.new(id: "http://data.agroportal.eu/categories/#{acronym}",
                   acronym: acronym,
                   name: acronym.capitalize,
                   description: "Sample category #{acronym}",
                   ontologies: ontologies.map { |o| "http://data.agroportal.eu/ontologies/#{o}" },
                   is_slice: false,
                   children: children)
  end

  def ontologies_names
    { 'http://data.agroportal.eu/ontologies/AGROVOC' => 'AGROVOC',
      'http://data.agroportal.eu/ontologies/CROPONT' => 'Crop Ontology' }
  end
end
