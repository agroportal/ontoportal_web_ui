require 'sparql/grammar'
module SparqlHelper
  def change_from_clause(query, graph)
    validate_sparql_query(query)
    query = remove_sparql_comments(query)
    # Clean up any blank lines that might have been created
    query.gsub!(/\n\s*\n+/, "\n")

    unless graph.blank?
      graph = graph.gsub($REST_URL, 'http://data.bioontology.org')

      if query.match?(/(?<=\s|^)FROM\s*\S+[^{ \n]/i)
        #  match FROM <URI> and FROM meta:User (only after space or start of line)
        query.gsub!(/(?<=\s|^)FROM\s*\S+[^{ \n]/i, "FROM <#{graph}>")
      elsif query.match?(/WHERE\s+\S+/i)
        # match WHERE without FROM
        query.gsub!(/WHERE/i, "FROM <#{graph}> WHERE")
      end
      # match GRAPH <URI> and GRAPH meta:User (only after space or start of line)
      query.gsub!(/(?<=\s|^)GRAPH\s*[^\{]+\{/i, "GRAPH <#{graph}> {")

      # match SELECT without FROM and WHERE and ignore the { inside quotes
      if query.match?(/(SELECT.*?\s*\S*)(?<!["'\s])\s*\{(?![^"]*["'])/im)
        query.sub!(/(SELECT.*?\s*\S*)(?<!["'\s])\s*\{(?![^"]*["'])/im) do |match|
          if match.downcase.match?(/(?<!["'(\s])\s*FROM(?![^"]*["')])/i)
            match
          else
            out = "#{$1}"
            out = out.gsub(/WHERE/i, '') if out.downcase.include?('where')
            "#{out.strip} FROM <#{graph}> WHERE {"
          end
        end
      end
    end

    validate_sparql_query(query)
    query
  end

  def ontology_sparql_query(query, graph = '')
    query = change_from_clause(query, graph)
    sparql_query(query)
  rescue StandardError
    'Failed to parse query'
  end

  def sparql_query(query)
    return 'No SPARQL endpoint configured' if $SPARQL_URL.blank?
    return 'INSERT Queries not permitted' unless is_allowed_query?(query)

    endpoint = $SPARQL_URL.gsub('test', 'sparql')
    begin
      conn = Faraday.new do |conn|
        conn.options.timeout = 10
      end
      response = conn.get("#{endpoint}?query=#{encode_param(query)}")
      response.body.force_encoding('ISO-8859-1').encode('UTF-8')
    rescue StandardError
      'Query timeout'
    end
  end

  def sparql_query_container(username: current_user&.username, graph: nil, apikey: get_apikey, sample_queries: nil, sparql_endpoint: $SPARQL_ENDPOINT_URL)
    if sample_queries.nil?
      sample_queries = get_catalog_sample_queries
    end

    yasgui_div = content_tag(:div, '', data: { 'sparql-target': 'yasgui' })
    inner = ai_sparql_enabled? ? safe_join([ai_sparql_assistant_panel, yasgui_div]) : yasgui_div

    content_tag(:div, inner,
                data: { controller: 'sparql',
                        'sparql-proxy-value': sparql_endpoint,
                        'sparql-apikey-value': apikey,
                        'sparql-username-value': username,
                        'sparql-graph-value': graph,
                        'sparql-sample-queries-value': sample_queries,
                        'sparql-ai-enabled-value': ai_sparql_enabled?,
                        'sparql-ai-generate-url-value': (generate_sparql_query_path if ai_sparql_enabled?)
                      })
  end

  def ai_sparql_assistant_panel
    header = content_tag(:div, class: 'sparql-ai-assistant__header') do
      safe_join([
        content_tag(:span, t('sparql_endpoint.ai_assistant.title'), class: 'sparql-ai-assistant__title'),
        content_tag(:span, t('sparql_endpoint.ai_assistant.hint'), class: 'sparql-ai-assistant__hint')
      ])
    end

    body = content_tag(:div, class: 'sparql-ai-assistant__body') do
      safe_join([
        text_area_tag('ai_sparql_prompt', nil,
                      placeholder: t('sparql_endpoint.ai_assistant.placeholder'),
                      rows: 2,
                      class: 'sparql-ai-assistant__input',
                      data: { 'sparql-target': 'aiPrompt', action: 'keydown.enter->sparql#aiGenerate' }),
        button_tag(t('sparql_endpoint.ai_assistant.generate'),
                   type: 'button',
                   class: 'sparql-ai-assistant__button',
                   data: { 'sparql-target': 'aiButton', action: 'click->sparql#aiGenerate' })
      ])
    end

    status = content_tag(:div, '', class: 'sparql-ai-assistant__status', data: { 'sparql-target': 'aiStatus' })

    content_tag(:div, safe_join([header, body, status]),
                class: 'sparql-ai-assistant', data: { 'sparql-target': 'aiPanel' })
  end
  NO_CACHE_HEADERS = {
    'Cache-Control' => 'no-cache, no-store, must-revalidate',
    'Pragma' => 'no-cache',
    'Expires' => '0'
  }.freeze
  def get_catalog_sample_queries
    begin
      response = LinkedData::Client::HTTP.get("#{$REST_URL}", {include: "sampleQueries", display_context: false, display_links: false, _ts: Time.now.to_i})
      response.to_hash[:sampleQueries]
    rescue => e
      logger.error "Failed to fetch catalog sample queries: #{e.message}"
      []
    end
  end

  def get_ontology_sample_queries(graph)
    begin
      response = LinkedData::Client::Models::Ontology.find_by_acronym(graph.gsub($REST_URL + '/ontologies/', '').split("/")[0], {include: "sampleQueries", display_context: false, display_links: false, _ts: Time.now.to_i}).first.sampleQueries
    rescue => e
      logger.error "Failed to fetch ontology sample queries: #{e.message}"
      []
    end
  end

  def ai_sparql_enabled?
    $AI_SPARQL_BASE_URL.present? && $AI_SPARQL_API_KEY.present? && $AI_SPARQL_MODEL.present?
  end

  def generate_sparql_from_prompt(prompt, graph: nil, current_query: nil)
    raise 'AI SPARQL generator is not configured' unless ai_sparql_enabled?

    system_message = <<~PROMPT.strip
      You are an expert SPARQL 1.1 query generator for OntoPortal / AgroPortal —
      an RDF triplestore holding metadata about biomedical and agronomic
      ontologies (the ontology content itself is stored as SKOS/OWL in
      per-ontology graphs).

      # Output contract
      - Output ONLY the SPARQL query. No prose, no markdown fences, no leading comments.
      - Always include every PREFIX the query references.
      - Default to SELECT unless the user explicitly requests CONSTRUCT, ASK, or DESCRIBE.
      - Always include LIMIT (default 100) unless the user specifies otherwise.
      - NEVER emit INSERT, DELETE, LOAD, CLEAR, CREATE, DROP, COPY, MOVE, or ADD.
      - If the request is impossible to translate (asks for data outside the model),
        still emit a valid query that returns no results, e.g.
        `SELECT * WHERE { FILTER(false) } LIMIT 1`. Never apologise in prose.

      # How to reason (do not emit)
      1. Identify the target entity: Ontology, OntologySubmission, Agent, Project, Metrics, etc.
      2. Pick the named graph(s) that hold those triples.
      3. Pick predicates from the reference below — do not invent predicates.
      4. Most descriptive metadata lives on OntologySubmission, not Ontology.
         Join through `?sub meta:ontology ?ont`.
      5. An Ontology usually has many submissions. Unless the user says otherwise,
         restrict to the latest submission (highest `meta:submissionId`).
      6. Unless the user says otherwise, restrict to public ontologies
         (`meta:viewingRestriction "public"`) and exclude views
         (`FILTER NOT EXISTS { ?ont meta:viewOf ?_ }`).

      # Prefixes (include only those actually used)
      PREFIX rdf:      <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
      PREFIX rdfs:     <http://www.w3.org/2000/01/rdf-schema#>
      PREFIX owl:      <http://www.w3.org/2002/07/owl#>
      PREFIX xsd:      <http://www.w3.org/2001/XMLSchema#>
      PREFIX skos:     <http://www.w3.org/2004/02/skos/core#>
      PREFIX foaf:     <http://xmlns.com/foaf/0.1/>
      PREFIX dct:      <http://purl.org/dc/terms/>
      PREFIX dc:       <http://purl.org/dc/elements/1.1/>
      PREFIX pav:      <http://purl.org/pav/>
      PREFIX prov:     <http://www.w3.org/ns/prov#>
      PREFIX adms:     <http://www.w3.org/ns/adms#>
      PREFIX org:      <http://www.w3.org/ns/org#>
      PREFIX schema:   <http://schema.org/>
      PREFIX cc:       <http://creativecommons.org/ns#>
      PREFIX doap:     <http://usefulinc.com/ns/doap#>
      PREFIX voaf:     <http://purl.org/vocommons/voaf#>
      PREFIX vann:     <http://purl.org/vocab/vann/>
      PREFIX idot:     <http://identifiers.org/idot/>
      PREFIX void:     <http://rdfs.org/ns/void#>
      PREFIX mod:      <https://w3id.org/mod#>
      PREFIX sd:       <http://www.w3.org/ns/sparql-service-description#>
      PREFIX door:     <http://kannel.open.ac.uk/ontology#>
      PREFIX oboInOwl: <http://www.geneontology.org/formats/oboInOwl#>
      PREFIX omv:      <http://omv.ontoware.org/2005/05/ontology#>
      PREFIX meta:     <http://data.bioontology.org/metadata/>

      # Data model

      Three central entity types:
      - **Ontology** (rdf:type meta:Ontology) — long-lived record (acronym, name, group, category, view relationships).
      - **OntologySubmission** (rdf:type meta:OntologySubmission) — one uploaded version of an Ontology. Carries almost all descriptive metadata. Linked back via `meta:ontology`.
      - **Agent** (rdf:type foaf:Agent) — person or organization, referenced by hasCreator / hasContributor / publisher / fundedBy / etc.

      Plus: Project (meta:Project), Note, Review, Group, Category, Metrics, Mapping, SubmissionStatus.

      ## Ontology predicates  (graph: meta:Ontology)
      - `omv:acronym`            short ID, e.g. "AGROVOC"
      - `omv:name`               display name
      - `meta:administeredBy`    -> user URI
      - `meta:group`             -> group URI (list)
      - `omv:hasDomain`          -> category URI (list)
      - `meta:viewingRestriction` literal: "public" | "private" | "licensed"
      - `meta:viewOf`            -> ontology URI (this is a view of another)
      - `meta:ontologyType`      -> type URI ("ONTOLOGY" | "VIEW")
      - `meta:flat`              xsd:boolean
      - `meta:summaryOnly`       xsd:boolean
      - `mod:sampleQueries`      string list

      ## OntologySubmission predicates  (graph: meta:OntologySubmission)
      Linkage (essential):
      - `meta:ontology`          -> Ontology URI         [required to join]
      - `meta:submissionId`      xsd:integer             [higher = newer]

      Identification: `omv:URI`, `owl:versionIRI`, `omv:version`, `omv:status`,
        `owl:deprecated`, `omv:hasOntologyLanguage`, `omv:hasOntologySyntax`,
        `omv:naturalLanguage`, `omv:isOfType`, `dct:identifier`

      Description: `omv:description`, `foaf:homepage`, `omv:documentation`,
        `omv:notes`, `omv:keywords`, `skos:hiddenLabel`, `dct:alternative`,
        `dct:abstract`, `:publication`

      Licensing: `omv:hasLicense`, `cc:useGuidelines`, `cc:morePermissions`,
        `schema:copyrightHolder` -> Agent

      Dates (xsd:dateTime): `meta:released`, `dct:valid`, `pav:curatedOn`,
        `omv:creationDate`, `omv:modificationDate`

      Agents (all -> Agent URI, most are lists):
        `omv:hasCreator`, `omv:hasContributor`, `pav:curatedBy`, `dct:publisher`,
        `foaf:fundedBy`, `omv:endorsedBy`, `schema:translator`, `meta:contact`

      Community: `dct:audience`, `doap:repository`, `doap:bugDatabase`,
        `doap:mailingList`, `voaf:toDoList`, `schema:award`

      Usage: `omv:knownUsage`, `omv:designedForOntologyTask`, `omv:hasDomain`,
        `dct:coverage`, `vann:example`

      Methodology: `omv:conformsToKnowledgeRepresentationParadigm`,
        `omv:usedOntologyEngineeringMethodology`, `omv:usedOntologyEngineeringTool`,
        `dct:accrualMethod`, `dct:accrualPeriodicity`, `dct:accrualPolicy`,
        `mod:competencyQuestion`, `prov:wasGeneratedBy`, `prov:wasInvalidatedBy`

      Links: `meta:pullLocation`, `dct:isFormatOf`, `dct:hasFormat`,
        `void:dataDump`, `void:uriLookupEndpoint`, `void:openSearchDescription`,
        `dct:source`, `sd:endpoint`, `schema:includedInDataCatalog`

      Ontology-to-ontology relations (all -> Ontology IRI, mostly lists):
        `omv:hasPriorVersion`, `dct:hasPart`, `door:ontologyRelatedTo`,
        `door:similarTo`, `door:comesFromTheSameDomain`, `door:isAlignedTo`,
        `omv:isBackwardCompatibleWith`, `omv:isIncompatibleWith`,
        `door:hasDisparateModelling`, `voaf:hasDisjunctionsWith`,
        `voaf:generalizes`, `door:explanationEvolution`, `omv:useImports`,
        `voaf:usedBy`, `schema:workTranslation`, `schema:translationOfWork`

      Content: `void:uriRegexPattern`, `vann:preferredNamespaceUri`,
        `vann:preferredNamespacePrefix`, `idot:exampleIdentifier`,
        `omv:keyClasses`, `voaf:metadataVoc`

      Media: `schema:associatedMedia`, `foaf:depiction`, `foaf:logo`

      Metrics / status:
        `meta:metrics` -> Metrics resource (graph: meta:Metrics)
        `meta:submissionStatus` -> SubmissionStatus URI (graph: meta:SubmissionStatus)

      ## Agent predicates  (graph: foaf:Agent)
      - `foaf:name`, `foaf:homepage`, `foaf:mbox` (email), `skos:altLabel` (acronym)
      - `meta:agentType`         "person" | "organization"
      - `adms:identifier`        -> Identifier resource (ORCID, ROR, …)
      - `org:memberOf`           -> Agent (affiliation)

      ## Project predicates  (graph: meta:Project)
      - `meta:acronym`, `meta:name`, `meta:description`, `meta:homePage`
      - `meta:creator` -> user, `meta:created`, `meta:updated`
      - `meta:contacts`, `meta:institution`
      - `meta:ontologyUsed` -> Ontology URI (list)

      # Named graphs

      Scope with `GRAPH <iri> { ... }`. Use multiple GRAPH blocks for cross-graph
      joins.

      - <http://data.bioontology.org/metadata/Ontology>            Ontology records
      - <http://data.bioontology.org/metadata/OntologySubmission>  Submission records
      - <http://xmlns.com/foaf/0.1/Agent>                          Agents
      - <http://data.bioontology.org/metadata/Project>             Projects
      - <http://data.bioontology.org/metadata/Category>            Categories
      - <http://data.bioontology.org/metadata/Group>               Groups
      - <http://data.bioontology.org/metadata/Metrics>             Metrics
      - <http://data.bioontology.org/metadata/SubmissionStatus>    Status URIs
      - <http://data.bioontology.org/metadata/OntologyFormat>      Format URIs
      - <http://data.bioontology.org/metadata/Note>                Notes
      - <http://data.bioontology.org/metadata/Review>              Reviews
      - <http://data.bioontology.org/metadata/Contact>             Contacts
      - <http://data.bioontology.org/metadata/Details>             Class details
      - <http://data.bioontology.org/metadata/MappingProcess>,
        <http://data.bioontology.org/metadata/ExternalMappings>,
        <http://data.bioontology.org/metadata/MappingCount>,
        <http://data.bioontology.org/metadata/RestBackupMapping>,
        <http://data.bioontology.org/metadata/InterportalMappings/ncbo>,
        <http://data.bioontology.org/metadata/InterportalMappings/sifr>   Mappings
      - <http://data.bioontology.org/metadata/ProvisionalClass>    Provisional classes
      - <http://data.bioontology.org/metadata/Slice>               Slices
      - <http://data.bioontology.org/metadata/Subscription>,
        <http://data.bioontology.org/metadata/NotificationType>,
        <http://data.bioontology.org/metadata/Reply>,
        <http://data.bioontology.org/metadata/OntologyType>,
        <http://data.bioontology.org/metadata/MappingProcess>,
        <http://data.bioontology.org/metadata/Base>                Misc
      - <http://www.w3.org/ns/adms#Identifier>                     Agent identifiers (ORCID, ROR)

      # Common building blocks

      Latest submission per ontology:
        ?sub meta:ontology ?ont ; meta:submissionId ?sid .
        FILTER NOT EXISTS {
          ?sub2 meta:ontology ?ont ; meta:submissionId ?sid2 .
          FILTER(?sid2 > ?sid)
        }

      Public, non-view ontologies:
        ?ont meta:viewingRestriction "public" .
        FILTER NOT EXISTS { ?ont meta:viewOf ?_anyView }

      Case-insensitive text match:
        FILTER(CONTAINS(LCASE(STR(?desc)), "plant"))

      # Examples

      ## Ex 1 — list ontologies with acronym and name
      PREFIX omv:  <http://omv.ontoware.org/2005/05/ontology#>
      PREFIX meta: <http://data.bioontology.org/metadata/>
      SELECT ?acronym ?name WHERE {
        GRAPH <http://data.bioontology.org/metadata/Ontology> {
          ?ont a meta:Ontology ;
               omv:acronym ?acronym ;
               omv:name ?name ;
               meta:viewingRestriction "public" .
          FILTER NOT EXISTS { ?ont meta:viewOf ?_v }
        }
      }
      ORDER BY ?acronym
      LIMIT 100

      ## Ex 2 — description + license of the latest submission per ontology
      PREFIX omv:  <http://omv.ontoware.org/2005/05/ontology#>
      PREFIX meta: <http://data.bioontology.org/metadata/>
      SELECT ?acronym ?description ?license WHERE {
        GRAPH <http://data.bioontology.org/metadata/Ontology> {
          ?ont a meta:Ontology ;
               omv:acronym ?acronym ;
               meta:viewingRestriction "public" .
        }
        GRAPH <http://data.bioontology.org/metadata/OntologySubmission> {
          ?sub meta:ontology ?ont ;
               meta:submissionId ?sid ;
               omv:description ?description .
          OPTIONAL { ?sub omv:hasLicense ?license }
          FILTER NOT EXISTS {
            ?sub2 meta:ontology ?ont ; meta:submissionId ?sid2 .
            FILTER(?sid2 > ?sid)
          }
        }
      }
      LIMIT 100

      ## Ex 3 — ontologies created by an Agent matched by name fragment
      PREFIX omv:  <http://omv.ontoware.org/2005/05/ontology#>
      PREFIX meta: <http://data.bioontology.org/metadata/>
      PREFIX foaf: <http://xmlns.com/foaf/0.1/>
      SELECT DISTINCT ?acronym ?name ?agentName WHERE {
        GRAPH <http://xmlns.com/foaf/0.1/Agent> {
          ?agent a foaf:Agent ; foaf:name ?agentName .
          FILTER(CONTAINS(LCASE(STR(?agentName)), "inrae"))
        }
        GRAPH <http://data.bioontology.org/metadata/OntologySubmission> {
          ?sub meta:ontology ?ont ; omv:hasCreator ?agent .
        }
        GRAPH <http://data.bioontology.org/metadata/Ontology> {
          ?ont omv:acronym ?acronym ; omv:name ?name .
        }
      }
      LIMIT 100

      ## Ex 4 — submission counts per ontology, sorted
      PREFIX omv:  <http://omv.ontoware.org/2005/05/ontology#>
      PREFIX meta: <http://data.bioontology.org/metadata/>
      SELECT ?acronym ?name (COUNT(DISTINCT ?sub) AS ?nSubs) WHERE {
        GRAPH <http://data.bioontology.org/metadata/Ontology> {
          ?ont omv:acronym ?acronym ; omv:name ?name .
        }
        GRAPH <http://data.bioontology.org/metadata/OntologySubmission> {
          ?sub meta:ontology ?ont .
        }
      }
      GROUP BY ?ont ?acronym ?name
      ORDER BY DESC(?nSubs)
      LIMIT 100

      ## Ex 5 — class counts via Metrics, for the latest submission
      PREFIX omv:  <http://omv.ontoware.org/2005/05/ontology#>
      PREFIX meta: <http://data.bioontology.org/metadata/>
      SELECT ?acronym ?classCount WHERE {
        GRAPH <http://data.bioontology.org/metadata/Ontology> {
          ?ont omv:acronym ?acronym ; meta:viewingRestriction "public" .
        }
        GRAPH <http://data.bioontology.org/metadata/OntologySubmission> {
          ?sub meta:ontology ?ont ;
               meta:submissionId ?sid ;
               meta:metrics ?metrics .
          FILTER NOT EXISTS {
            ?sub2 meta:ontology ?ont ; meta:submissionId ?sid2 .
            FILTER(?sid2 > ?sid)
          }
        }
        GRAPH <http://data.bioontology.org/metadata/Metrics> {
          ?metrics meta:classes ?classCount .
        }
      }
      ORDER BY DESC(?classCount)
      LIMIT 100

      # Additional context handling
      - If a CURRENT_QUERY is provided below, treat the user prompt as an EDIT
        request: keep the same overall shape and bound variables, change only
        what the user asks for.
      - If a TARGET_GRAPH is provided, scope the query to that graph unless
        the user explicitly asks for cross-graph data.

      # Disambiguation policy
      When the request is vague, pick the most useful reasonable interpretation
      with safe defaults (public, non-view, latest submission, ORDER BY acronym
      or DESC count). Do not ask the user — just produce the query.
    PROMPT

    system_message += "\n\nTARGET_GRAPH: <#{graph}>" if graph.present?
    system_message += "\n\nCURRENT_QUERY:\n#{current_query}" if current_query.present?

    user_content = "Request: #{prompt.to_s.strip}"

    endpoint = "#{$AI_SPARQL_BASE_URL.to_s.chomp('/')}/chat/completions"
    payload = {
      model: $AI_SPARQL_MODEL,
      temperature: 0.1,
      messages: [
        { role: 'system', content: system_message },
        { role: 'user', content: user_content }
      ]
    }

    conn = Faraday.new do |c|
      c.options.timeout = 60
      c.options.open_timeout = 10
    end

    response = conn.post(endpoint) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['Authorization'] = "Bearer #{$AI_SPARQL_API_KEY}"
      req.body = payload.to_json
    end

    unless response.success?
      raise "AI service returned HTTP #{response.status}"
    end

    body = JSON.parse(response.body)
    content = body.dig('choices', 0, 'message', 'content').to_s
    raise 'AI service returned empty response' if content.strip.empty?

    sparql = extract_sparql_from_completion(content)
    validate_sparql_query(sparql)
    sparql
  end

  private

  def extract_sparql_from_completion(content)
    text = content.to_s.strip
    if (m = text.match(/```(?:sparql)?\s*(.*?)```/im))
      text = m[1].strip
    end
    text
  end

  def is_allowed_query?(sparql_query)
    forbidden_operations = [
      'INSERT DATA',
      'DELETE DATA',
      'DELETE/INSERT',
      'DELETE',
      'INSERT',
      'DELETE WHERE',
      'LOAD',
      'CLEAR',
      'CREATE',
      'DROP',
      'COPY',
      'MOVE',
      'ADD'
    ]

    # Define a regular expression to match SELECT queries
    select_query_regex = /\A\s*SELECT\b/m

    # Check if the query contains any forbidden operations outside SELECT queries
    if forbidden_operations.any? { |op| sparql_query.upcase.include?(op) && !sparql_query.match(select_query_regex) }
      return false
    end

    true
  end

  def remove_sparql_comments(query)
    # Remove everything from # to end of line, unless the # is inside angle brackets
    lines = query.split("\n")
    cleaned_lines = lines.map do |line|
      inside_uri = false
      comment_start = nil

      line.each_char.with_index do |char, i|
        if char == '<'
          inside_uri = true
        elsif char == '>'
          inside_uri = false
        elsif char == '#' && !inside_uri
          comment_start = i
          break
        end
      end

      comment_start ? line[0...comment_start] : line
    end

    cleaned_lines.join("\n")
  end

  def validate_sparql_query(query)
    SPARQL::Grammar.parse(query)
  rescue StandardError => e
    raise StandardError, "Failed to parse query: #{e.message}"
  end

end
