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
    name = $SITE.presence || $ORG_SITE.presence
    url  = $UI_URL.presence
    return if name.blank? || url.blank?

    {
      '@context' => 'https://schema.org',
      '@type' => 'DataCatalog',
      '@id' => url,
      'name' => name,
      'url' => url,
      'description' => clean_text(t('home.catalog.description', site: name, default: '')),
      'keywords' => home_catalog_keywords,
      'isAccessibleForFree' => true,
      'publisher' => home_catalog_publisher,
    }.compact
  end

  def home_catalog_keywords
    Array(t('home.catalog.keywords', default: [])).flat_map { |k| k.to_s.split(',') }
                                                  .filter_map { |k| clean_text(k) }.uniq.presence
  end

  def home_catalog_publisher
    name = clean_text($ORG.presence)
    return if name.blank?

    { '@type' => 'Organization', 'name' => name, 'url' => $ORG_URL.presence }.compact
  end

  def ontology_dataset_graph(ontology, submission)
    url = ontology_metadata_url(ontology)
    {
      '@context' => { '@vocab' => 'https://schema.org/', 'dct' => 'http://purl.org/dc/terms/' },
      '@type' => 'Dataset',
      '@id' => url,
      'dct:conformsTo' => { '@type' => 'CreativeWork', '@id' => BIOSCHEMAS_DATASET_PROFILE },
      'url' => url,
      'sameAs' => ld_urls(submission&.homepage),
      'name' => ontology_metadata_title(ontology),
      'identifier' => ontology.acronym,
      'alternateName' => ld_alternate_names(ontology, submission),
      'description' => ontology_metadata_description(submission, limit: nil),
      'keywords' => ontology_metadata_keywords(submission),
      'version' => clean_text(submission&.version),
      'license' => first_present(submission&.hasLicense),
      'usageInfo' => first_present(submission&.useGuidelines),
      'inLanguage' => Array(submission&.naturalLanguage).filter_map { |l| clean_text(l) }.presence,
      'image' => ontology_metadata_image(submission),
      'creator' => ld_agents(submission&.hasCreator),
      'publisher' => ld_agents(submission&.publisher),
      'contributor' => ld_agents(submission&.hasContributor),
      'editor' => ld_agents(submission&.curatedBy),
      'translator' => ld_agents(submission&.translator),
      'funder' => ld_agents(submission&.fundedBy),
      'copyrightHolder' => ld_agents(submission&.copyrightHolder),
      'award' => ld_texts(submission&.award),
      'audience' => ld_nodes(submission&.audience, 'Audience', 'audienceType'),
      'spatialCoverage' => ld_nodes(submission&.coverage, 'Place'),
      'datePublished' => clean_text(submission&.released),
      'dateCreated' => clean_text(submission&.creationDate),
      'dateModified' => clean_text(submission&.modificationDate),
      'includedInDataCatalog' => data_catalog_node,
      'distribution' => ld_distribution(submission)
    }.compact
  end

  def data_catalog_node
    { '@type' => 'DataCatalog', 'name' => $ORG_SITE.presence, 'url' => $UI_URL.presence }.compact.presence
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

  # Wrap each non-blank value in a typed node, e.g. a Place for dct:coverage or
  # an Audience for dct:audience, so the JSON-LD stays schema.org-valid.
  def ld_nodes(value, type, key = 'name')
    Array(value).filter_map { |v| text = clean_text(v); { '@type' => type, key => text } if text }.presence
  end

  def ld_agent(agent)
    if agent.is_a?(String)
      return if agent.blank?

      link?(agent) ? { '@id' => agent } : { '@type' => 'Organization', 'name' => agent }
    else
      type = agent.try(:agentType).to_s == 'organization' ? 'Organization' : 'Person'
      node = { '@type' => type, 'name' => clean_text(agent.try(:name)) }
      node['@id'] = agent.id.to_s if agent.try(:id).present?
      node.compact.presence
    end
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
    values = Array(submission&.keywords).flat_map { |k| k.to_s.split(',') } +
             Array(submission&.hasDomain)
    values.filter_map { |k| clean_text(k) }.uniq.presence
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
