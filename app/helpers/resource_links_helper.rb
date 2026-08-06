# frozen_string_literal: true

# Most URI values in a concept's or a property's rows are classes, and get a
# link to their page. The rest are usually *reified nodes* - a skos:Definition,
# a note, an annotation - resources that exist only to carry triples and have
# no page of their own. Today those render as an external link to the raw URI,
# which leads nowhere useful.
#
# Such a node is recognised by two things:
#
#   1. it lives in the same namespace as the resource being displayed - a URI
#      minted by another vocabulary (owl:Thing, skos:Concept) never belongs to
#      this ontology, and probing the API for it would be wasted;
#   2. the API knows it - +/ontologies/:acronym/instances/:uri+ answers for any
#      resource of the submission, whatever its rdf:type, and 404s otherwise.
#
# It is then shown the way a SKOS-XL label is: a chip opening a modal that
# lists every triple the node holds.
module ResourceLinksHelper
  # A chip opening the node's triples in a modal, or nil when +uri+ is not a
  # reified node of this ontology (the caller then falls back to its own
  # rendering).
  def reified_resource_chip(acronym, uri, parent_uri: nil)
    return nil unless same_namespace?(uri, parent_uri)

    resource = ontology_resource(acronym, uri)
    return nil if resource.nil?

    ajax_link_chip(uri, resource_chip_label(resource, uri),
                   resource_modal_path(acronym, uri), open_in_modal: true)
  end

  # Everything up to and including the last '#' or '/': the part two URIs minted
  # by the same ontology share.
  #
  #   uri_namespace('http://opendata.inrae.fr/thesaurusINRAE/note_101800en')
  #   #=> "http://opendata.inrae.fr/thesaurusINRAE/"
  def uri_namespace(uri)
    uri.to_s[%r{\A.*[#/]}]
  end

  def same_namespace?(uri, other)
    return false unless http_uri?(uri)
    return true if other.blank? # nothing to compare against: let the API decide

    namespace = uri_namespace(uri)
    namespace.present? && namespace == uri_namespace(other)
  end

  def http_uri?(value)
    value.to_s.start_with?('http://', 'https://')
  end

  # The instances endpoint serves any resource of the submission, so it is what
  # backs the modal - reusing the page instances already have.
  def resource_modal_path(acronym, uri)
    "/ontologies/#{acronym}/instances/show?instanceid=#{escape(uri)}&modal=true"
  end

  private

  # The node, or nil when neither the REST API nor SPARQL knows it. See
  # ResourceLookupService for why one source is not enough.
  def ontology_resource(acronym, uri)
    ResourceLookupService.call(acronym, uri)
  end

  def resource_chip_label(resource, uri)
    label = main_language_label(resource['label'].presence || resource['prefLabel'])
    label = label.first if label.is_a?(Array)

    label.presence || extract_label_from(uri)
  end
end
