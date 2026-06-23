# frozen_string_literal: true

# Builds SEO / social / linked-data metadata for ontology pages:
#   * <meta name="description">
#   * Open Graph + Twitter Card tags
#   * <link rel="canonical">
#   * a schema.org Dataset JSON-LD block, flagged as conformant to the
#     Bioschemas Dataset profile
#
# Everything is derived from the in-memory @ontology / @submission_latest
# objects already loaded by OntologiesController#show, so this adds no extra
# API calls. The latest submission can be missing or only partially loaded, so
# every field is null-guarded and blank values are dropped from the output.
module MetadataTagsHelper
  BIOSCHEMAS_DATASET_PROFILE = 'https://bioschemas.org/profiles/Dataset/1.0-RELEASE'
  META_DESCRIPTION_LIMIT = 300

  # Characters escaped before the JSON-LD is embedded in a <script> tag, so
  # nothing can close the element early or break parsing: < > & and the U+2028 /
  # U+2029 line separators (valid in JSON, invalid in JavaScript string literals).
  JSON_LD_UNSAFE = Regexp.union("<", ">", "&", 0x2028.chr(Encoding::UTF_8), 0x2029.chr(Encoding::UTF_8)).freeze

  # Emits every <head> tag we generate for an ontology page. Returns nil for
  # non-ontology pages (or an unresolved ontology) so it is safe to call from a
  # shared layout.
  def ontology_head_metadata(ontology, submission)
    return if ontology.blank? || ontology.acronym.blank?

    safe_join([ontology_meta_tags(ontology, submission),
               ontology_json_ld(ontology, submission)].compact, "\n")
  end

  # Description / canonical / Open Graph / Twitter Card tags.
  def ontology_meta_tags(ontology, submission)
    url         = ontology_metadata_url(ontology)
    title       = ontology_metadata_title(ontology)
    description = ontology_metadata_description(submission)
    image       = ontology_metadata_image(submission)

    tags = []
    tags << tag.link(rel: 'canonical', href: url) if url.present?
    tags << tag.meta(name: 'description', content: description) if description.present?

    tags << tag.meta(property: 'og:type', content: 'website')
    tags << tag.meta(property: 'og:site_name', content: $ORG_SITE) if $ORG_SITE.present?
    tags << tag.meta(property: 'og:title', content: title) if title.present?
    tags << tag.meta(property: 'og:url', content: url) if url.present?
    tags << tag.meta(property: 'og:description', content: description) if description.present?
    tags << tag.meta(property: 'og:image', content: image) if image.present?

    tags << tag.meta(name: 'twitter:card', content: image.present? ? 'summary_large_image' : 'summary')
    tags << tag.meta(name: 'twitter:title', content: title) if title.present?
    tags << tag.meta(name: 'twitter:description', content: description) if description.present?
    tags << tag.meta(name: 'twitter:image', content: image) if image.present?

    safe_join(tags, "\n")
  end

  # schema.org Dataset JSON-LD, flagged as conformant to the Bioschemas Dataset profile.
  def ontology_json_ld(ontology, submission)
    data = ontology_dataset_graph(ontology, submission)
    return if data.blank?

    content_tag(:script, raw(safe_ld_json(data)), type: 'application/ld+json')
  end

  # schema.org DataCatalog JSON-LD describing the portal itself, for the
  # homepage <head>. Descriptive text comes from the locale files; identity from
  # the $SITE / $UI_URL / $ORG globals. Returns nil if the portal is unnamed or
  # has no UI URL, so it is safe to call unconditionally.
  def home_catalog_json_ld
    data = home_catalog_graph
    return if data.blank?

    content_tag(:script, raw(safe_ld_json(data)), type: 'application/ld+json')
  end

  private

  def home_catalog_graph
    config = portal_catalog_config
    name = clean_text(config[:title]) || $SITE.presence || $ORG_SITE.presence
    url  = config[:ui].presence || $UI_URL.presence
    return if name.blank? || url.blank?

    {
      '@context' => 'https://schema.org',
      '@type' => 'DataCatalog',
      '@id' => url,
      'identifier' => first_present(config[:identifier]),        # dcterms:identifier
      'name' => name,                                            # dcterms:title
      'url' => url,                                              # foaf:homepage / portal UI
      'documentation' => first_present(config[:landingPage]),    # dcat:landingPage
      'description' => clean_text(config[:description]) || clean_text(t('home.catalog.description', site: name, default: '')), # dcterms:description
      'about' => ld_texts(config[:subject]),                     # dcterms:subject
      'keywords' => home_catalog_keywords(config),               # dcat:keyword
      'inLanguage' => ld_texts(config[:language]),               # dcterms:language
      'license' => first_present(config[:license]),              # dcterms:license
      'citation' => ld_texts(config[:bibliographicCitation]),    # dcterms:bibliographicCitation
      'spatialCoverage' => ld_nodes(config[:coverage], 'Place'), # dcterms:coverage
      'dateCreated' => clean_text(config[:created]),             # dcterms:created
      'creator' => ld_agents(config[:creator]),                  # dcterms:creator
      'author' => ld_agents(config[:creator]),                   # dcterms:creator
      'contributor' => ld_agents(config[:contributor]),          # dcterms:contributor
      'funder' => ld_agents(config[:fundedBy]),                  # foaf:fundedBy
      'contactPoint' => ld_contact_points(config[:contactPoint]), # dcat:contactPoint (Agent w/ email)
      'publisher' => home_catalog_publisher,                     # dcterms:publisher
    }.compact
  end

  # Catalog keywords from the live portal config when present, otherwise the
  # locale-provided fallback list.
  def home_catalog_keywords(config = {})
    raw = Array(config[:keywords]).presence || Array(t('home.catalog.keywords', default: []))
    raw.flat_map { |k| k.to_s.split(',') }.filter_map { |k| clean_text(k) }.uniq.presence
  end

  def home_catalog_publisher
    name = clean_text($ORG.presence)
    return if name.blank?

    { '@type' => 'Organization', 'name' => name, 'url' => $ORG_URL.presence }.compact
  end

  # Maps the AgroPortal / MOD submission metadata onto schema.org Dataset
  # properties, following the agreed MOD 3.0 <-> schema.org crosswalk. Every
  # value is null-guarded and blank entries are dropped by the final #compact.
  def ontology_dataset_graph(ontology, submission)
    url = ontology_metadata_url(ontology)
    {
      '@context' => { '@vocab' => 'https://schema.org/', 'dct' => 'http://purl.org/dc/terms/' },
      '@type' => 'Dataset',
      '@id' => url,
      'dct:conformsTo' => { '@type' => 'CreativeWork', '@id' => BIOSCHEMAS_DATASET_PROFILE },
      # Identity ------------------------------------------------------------
      'url' => url,
      'mainEntityOfPage' => ld_urls(submission&.homepage),          # foaf:homepage
      'name' => ontology_metadata_title(ontology),                  # omv:name
      'identifier' => ontology.acronym,                             # dcterms:identifier
      'alternateName' => ld_alternate_names(ontology, submission),  # dcterms:alternative
      'additionalType' => ld_texts(submission&.isOfType),           # omv:isOfType
      # Description ---------------------------------------------------------
      'description' => clean_text(submission&.description),          # omv:description
      'abstract' => clean_text(submission&.abstract),               # dcterms:abstract
      'comment' => ld_texts(submission&.notes),                     # bpm:notes
      'keywords' => ontology_metadata_keywords(submission),         # omv:keywords
      'about' => ld_texts(submission&.hasDomain),                   # omv:hasDomain (subject)
      # Status / rights -----------------------------------------------------
      'creativeWorkStatus' => clean_text(submission&.status),       # omv:status
      'conditionsOfAccess' => clean_text(submission&.viewingRestriction), # bpm:viewingRestriction
      'version' => clean_text(submission&.version),                 # omv:version
      'schemaVersion' => ld_texts(submission&.metadataVoc),         # voaf:metadataVoc
      'license' => first_present(submission&.hasLicense),           # omv:hasLicense
      'usageInfo' => first_present(submission&.useGuidelines),      # cc:useGuidelines
      'inLanguage' => Array(submission&.naturalLanguage).filter_map { |l| clean_text(l) }.presence, # omv:naturalLanguage
      # Media ---------------------------------------------------------------
      'logo' => ld_url(submission&.logo),                           # foaf:logo
      'image' => ld_urls(submission&.depiction),                    # foaf:depiction
      'associatedMedia' => ld_url_nodes(submission&.associatedMedia, 'MediaObject', 'contentUrl'),
      # Agents --------------------------------------------------------------
      'creator' => ld_agents(submission&.hasCreator),               # omv:hasCreator
      'author' => ld_agents(submission&.hasCreator),                # omv:hasCreator
      'publisher' => ld_agents(submission&.publisher),              # dcterms:publisher
      'contributor' => ld_agents(submission&.hasContributor),       # omv:hasContributor
      'maintainer' => ld_agents(submission&.curatedBy),             # pav:curatedBy
      'translator' => ld_agents(submission&.translator),            # schema:translator
      'funder' => ld_agents(submission&.fundedBy),                  # foaf:fundedBy
      'copyrightHolder' => ld_agents(submission&.copyrightHolder),  # schema:copyrightHolder
      'contactPoint' => ld_contact_points(submission&.contact),     # bpm:contact
      'award' => ld_texts(submission&.award),                       # schema:award
      'audience' => ld_nodes(submission&.audience, 'Audience', 'audienceType'), # dcterms:audience
      'spatialCoverage' => ld_nodes(submission&.coverage, 'Place'), # dcterms:coverage
      # Dates ---------------------------------------------------------------
      'datePublished' => clean_text(submission&.released),          # bpm:released
      'dateCreated' => clean_text(submission&.creationDate) || clean_text(submission&.created), # bpm:creationDate / dcterms:created
      'dateModified' => clean_text(submission&.modificationDate),   # omv:modificationDate
      # Provenance / relations ---------------------------------------------
      'documentation' => first_present(submission&.documentation),  # omv:documentation
      'citation' => ld_texts(submission&.publication),              # bpm:publication
      'codeRepository' => first_present(submission&.repository),    # doap:repository
      'instrument' => ld_nodes(submission&.usedOntologyEngineeringTool, 'Thing'), # pav:createdWith
      'isBasedOn' => ld_texts(submission&.source),                  # dcterms:source
      'isPartOf' => ld_texts(submission&.viewOf),                   # bpm:viewOf
      'hasPart' => ld_texts(submission&.hasPart),                   # dcterms:hasPart
      'isRelatedTo' => ld_texts(submission&.ontologyRelatedTo),     # door:ontologyRelatedTo
      'workExample' => ld_texts(submission&.example),               # vann:example
      'releaseNotes' => first_present(submission&.diffFilePath),    # bpm:diffFilePath
      'potentialAction' => ld_nodes(submission&.toDoList, 'Action'),# voaf:toDoList
      # Catalog / distribution ---------------------------------------------
      'includedInDataCatalog' => data_catalog_node,
      'distribution' => ld_distribution(submission)
    }.compact
  end

  def data_catalog_node
    config = portal_catalog_config
    name = clean_text(config[:title]) || $ORG_SITE.presence
    url  = config[:ui].presence || $UI_URL.presence
    { '@type' => 'DataCatalog', '@id' => url, 'name' => name, 'url' => url }.compact.presence
  end

  def ld_distribution(submission)
    url = first_present(submission&.dataDump)
    return if url.blank?

    [{ '@type' => 'DataDownload', 'contentUrl' => url,
       'encodingFormat' => clean_text(submission&.hasOntologyLanguage) }.compact]
  end

  def ld_agents(value)
    Array(value).filter_map { |agent| ld_agent(agent) }.presence
  end

  # The acronym plus any dcterms:alternative titles, deduped. Returns a bare
  # string when only the acronym is present so the common case stays compact.
  def ld_alternate_names(ontology, submission)
    names = ([ontology.try(:acronym)] + Array(submission&.alternative)).filter_map { |n| clean_text(n) }.uniq
    names.size > 1 ? names : names.first
  end

  # Cleaned, deduped plain-text values (e.g. schema:award).
  def ld_texts(value)
    Array(value).filter_map { |v| clean_text(v) }.uniq.presence
  end

  # Keep only the values that are absolute http(s) URLs (e.g. foaf:homepage).
  def ld_urls(value)
    Array(value).filter_map { |v| url = v.to_s.strip; url if url.present? && link?(url) }.uniq.presence
  end

  # First value that is an absolute http(s) URL (e.g. foaf:logo).
  def ld_url(value)
    ld_urls(value)&.first
  end

  # Wrap each absolute-URL value in a typed node keyed on +key+ (e.g. a
  # MediaObject with a contentUrl for schema:associatedMedia).
  def ld_url_nodes(value, type, key = 'url')
    Array(value).filter_map do |v|
      url = v.to_s.strip
      { '@type' => type, key => url } if url.present? && link?(url)
    end.presence
  end

  # schema:contactPoint nodes from bpm:contact records, each carrying a name
  # and/or an email. Records expose those as #[] (hash-like) or as readers.
  def ld_contact_points(value)
    Array(value).filter_map do |c|
      name  = clean_text(contact_field(c, :name))
      email = clean_text(contact_field(c, :email))
      next if name.blank? && email.blank?

      { '@type' => 'ContactPoint', 'name' => name, 'email' => email&.downcase }.compact
    end.presence
  end

  def contact_field(contact, key)
    if contact.respond_to?(:[])
      contact[key] || contact[key.to_s]
    elsif contact.respond_to?(key)
      contact.public_send(key)
    end
  end

  # Wrap each non-blank value in a typed node, e.g. a Place for dct:coverage or
  # an Audience for dct:audience, so the JSON-LD stays schema.org-valid.
  def ld_nodes(value, type, key = 'name')
    Array(value).filter_map { |v| text = clean_text(v); { '@type' => type, key => text } if text }.presence
  end

  def ld_agent(agent)
    return if agent.blank?

    case agent
    when String
      link?(agent) ? { '@id' => agent } : { '@type' => 'Organization', 'name' => agent }
    when Hash
      # Catalog agents/funders arrive as plain hashes once the resource has been
      # to_hash'd (funders may be {url:, img_src:} logo descriptors).
      ld_agent_node('Organization', name: agent[:name] || agent['name'],
                                    id: agent[:id] || agent['id'],
                                    url: agent[:url] || agent['url'],
                                    logo: agent[:img_src] || agent['img_src'])
    else
      type = agent.try(:agentType).to_s == 'organization' ? 'Organization' : 'Person'
      ld_agent_node(type, name: agent.try(:name), id: agent.try(:id))
    end
  end

  # Build a Person/Organization node, dropping it entirely when it carries no
  # identifying information (no name and no @id / url / logo).
  def ld_agent_node(type, name: nil, id: nil, url: nil, logo: nil)
    node = { '@type' => type,
             'name' => clean_text(name),
             '@id' => id.to_s.presence,
             'url' => url.to_s.presence,
             'logo' => logo.to_s.presence }.compact
    node.presence if (node.keys - ['@type']).any?
  end

  def ontology_metadata_url(ontology)
    return if ontology&.acronym.blank?

    base = $UI_URL.presence || (request.respond_to?(:base_url) ? request.base_url : nil)
    return if base.blank?

    "#{base.chomp('/')}/ontologies/#{ontology.acronym}"
  end

  def ontology_metadata_title(ontology)
    clean_text(ontology.try(:name)) || ontology.try(:acronym)
  end

  def ontology_metadata_description(submission, limit: META_DESCRIPTION_LIMIT)
    text = clean_text(submission&.description) || clean_text(submission&.abstract)
    return if text.blank?

    limit ? text.truncate(limit, separator: ' ') : text
  end

  def ontology_metadata_image(submission)
    logo = submission&.logo
    logo if logo.present? && link?(logo)
  end

  def ontology_metadata_keywords(submission)
    Array(submission&.keywords).flat_map { |k| k.to_s.split(',') }
                               .filter_map { |k| clean_text(k) }.uniq.presence
  end

  def clean_text(value)
    return if value.blank?

    strip_tags(value.to_s).squish.presence
  end

  def first_present(value)
    Array(value).filter_map { |v| v.to_s.presence }.first
  end

  # Serialise to JSON, then escape the characters that are unsafe inside an
  # inline <script> by replacing them with their \uXXXX form (still valid JSON).
  def safe_ld_json(data)
    JSON.generate(data).gsub(JSON_LD_UNSAFE) { |c| format('\u%04x', c.ord) }
  end
end
