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
      You are an expert SPARQL query generator for the OntoPortal/AgroPortal RDF triplestore,
      which stores biomedical and agronomic ontologies (SKOS/OWL data via the OntoPortal data model).
      Translate the user's natural-language request into a single, valid SPARQL 1.1 query.

      Strict rules:
      - Return ONLY the SPARQL query. No prose, no explanations, no markdown fences.
      - Always include relevant PREFIX declarations the query uses
        (rdf, rdfs, owl, skos, dcterms, xsd, and metadata: <http://data.bioontology.org/metadata/> when needed).
      - Use SELECT queries unless explicitly asked otherwise.
      - Always include a LIMIT clause (default 100) unless one is explicitly requested.
      - Never produce INSERT, DELETE, LOAD, CLEAR, CREATE, DROP, COPY, MOVE, or ADD operations.
    PROMPT

    user_parts = []
    user_parts << "Target graph: <#{graph}>" if graph.present?
    if current_query.present?
      user_parts << "Existing query for reference (modify if helpful):\n```\n#{current_query.to_s.strip}\n```"
    end
    user_parts << "Request: #{prompt.to_s.strip}"

    endpoint = "#{$AI_SPARQL_BASE_URL.to_s.chomp('/')}/chat/completions"
    payload = {
      model: $AI_SPARQL_MODEL,
      temperature: 0.1,
      messages: [
        { role: 'system', content: system_message },
        { role: 'user', content: user_parts.join("\n\n") }
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
