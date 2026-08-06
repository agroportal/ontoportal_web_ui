module InstancesHelper
  include ConceptsHelper
  include ApplicationHelper

  # A reified node - a skos:Definition, a note - carries its own text under one
  # of these, most specific first. The API maps none of them: of a resource it
  # names only rdf:type, rdfs:label and skos:prefLabel, and leaves everything
  # else undifferentiated in `properties`. So the choice of what counts as the
  # node's text is made here, not derived from the model.
  RESOURCE_VALUE_PREDICATES = %w[
    http://www.w3.org/1999/02/22-rdf-syntax-ns#value
    http://www.w3.org/2008/05/skos-xl#literalForm
    http://www.w3.org/2004/02/skos/core#definition
    http://www.w3.org/2004/02/skos/core#note
  ].freeze

  # [predicate, values] for the node's own text, or nil when it carries none -
  # an ordinary individual, whose text is its label. Everything else the node
  # holds stays where it came from, listed under Raw data.
  def resource_value(instance)
    properties = instance[:properties].to_h.transform_keys(&:to_s)

    RESOURCE_VALUE_PREDICATES.each do |uri|
      values = Array(properties[uri]).reject(&:blank?)
      return [uri, values] if values.present?
    end

    nil
  end

  def get_instance_details_json(ontology_acronym, instance_uri , query_parameters, raw: false)
    LinkedData::Client::HTTP
      .get("/ontologies/#{ontology_acronym}/instances/#{CGI.escape(instance_uri)}",
           query_parameters, raw: raw)
  end

  def get_instance_and_type(instance_id, acronym = @ontology.acronym)
    if instance_id.nil?
      [{}, nil]
    else
      instance_details = JSON.parse(get_instance_details_json(acronym,instance_id, {}, raw: true))
      if(!instance_details['types'].nil?)
        types = instance_details['types'].reject{ |type| type.eql? 'http://www.w3.org/2002/07/owl#NamedIndividual'}
        [instance_details, types[0]]
      else
        [{}, nil]
      end
    end
  end

  def instance_label(instance)
    labels = instance['label']
    labels = labels.first if labels.kind_of?(Array)
    labels || instance['prefLabel'] || extract_label_from(instance['@id'])
  end

  def type_of(instance)
    except_types = ['http://www.w3.org/2002/07/owl#NamedIndividual']
    out = instance['types'].filter{ |x| !except_types.include?(x)}
    if !out.empty?
       out.first
    else
       ""
    end
  end

  def link_to_instance(instance, ontology_acronym)
    link_to instance_label(instance),
            ontology_path(ontology_acronym, p: 'classes', conceptid:type_of(instance), instanceid:instance['@id']),
            {target: '_blank'}
  end

  def link_to_class(ontology_acronym, conceptid)
    link_to concept_label(ontology_acronym, conceptid),
            ontology_path(ontology_acronym, p: 'classes', conceptid:conceptid),
            {target: '_blank'}
  end

  def link_to_property(property, ontology_acronym)
    link_to extract_label_from(property),
            ontology_path(ontology_acronym, p: 'properties', propertyid: property),
            { target: '_blank'}
  end

  def instance_property_value(property, ontology_acronym)
    if link?(property)
      instance, types = get_instance_and_type(property, ontology_acronym)
      return link_to_instance(instance, ontology_acronym) unless instance.empty?
    end
    property
  end

end
