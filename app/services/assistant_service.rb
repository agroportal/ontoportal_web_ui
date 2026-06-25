# Runs the agentic loop between an OpenAI-compatible LLM and the AgroPortal MCP server.
#
# Tool calling is driven through the prompt rather than the OpenAI `tools` parameter:
# the available tools are described in the system prompt, and the model requests one by
# replying with a small JSON object ({"tool": ..., "arguments": {...}}) which we parse,
# execute against the MCP server, and feed back. This works with every OpenAI-compatible
# endpoint — including reasoning models (e.g. gpt-oss) whose servers do not surface
# native `tool_calls` — because it only relies on the model returning text content.
#
# The service is stateless: the caller passes the full dialogue on every turn, so
# conversation context is preserved client-side.
class AssistantService
  class Error < StandardError; end

  MAX_ROUNDS = 6
  MAX_TOOL_RESULT_CHARS = 8_000

  # Tool calls are delimited by these markers. END_MARKER is also sent as a `stop`
  # sequence so the model cannot run past a tool call into fabricated/echoed text.
  TOOL_MARKER = '[[TOOL]]'
  END_MARKER = '[[END]]'

  BASE_PROMPT = <<~PROMPT
    You are the AgroPortal assistant, embedded in the AgroPortal web portal.
    You help users explore ontologies hosted in AgroPortal.

    Never invent ontology acronyms, class URIs, definitions, or metrics. Use the tools
    below to look up real data, and cite acronyms and/or URIs from the tool results. If
    the tools return nothing relevant, say so plainly. Keep answers concise and well
    structured (short Markdown lists are fine). Answer in the user's language.
  PROMPT

  def initialize(user_apikey:, llm: nil, mcp: nil)
    @mcp = mcp || McpClient.new(server_url: $ASSISTANT_MCP_URL, apikey: user_apikey)
    @llm = llm || LlmClient.new(
      api_url: $ASSISTANT_LLM_API_URL,
      api_key: $ASSISTANT_LLM_API_KEY,
      model:   $ASSISTANT_LLM_MODEL
    )
  end

  # conversation: array of {"role" => "user"|"assistant", "content" => "..."} from the browser.
  # Returns { reply: String, tool_calls: [{ name:, arguments: }] } (the trace of tools used).
  def run(conversation)
    tools = @mcp.tools_for_openai
    @tool_names = tools.map { |t| t[:function][:name] }
    messages = [{ role: 'system', content: system_prompt(tools) }] + sanitize(conversation)
    trace = []

    MAX_ROUNDS.times do
      content = @llm.chat(messages: messages, stop: [END_MARKER])['content'].to_s
      call = extract_tool_call(content)

      return { reply: present(content), tool_calls: trace } if call.nil?

      trace << { name: call['tool'], arguments: call['arguments'] }
      result = execute_tool(call['tool'], call['arguments'])

      # Maintain clean user/assistant alternation for the prompt-based protocol.
      # Re-append END_MARKER (stripped by the stop sequence) so the stored tool call is well-formed.
      messages << { role: 'assistant', content: "#{content.strip}#{END_MARKER}" }
      messages << { role: 'user', content: tool_result_message(call['tool'], result) }
    end

    # Tool budget exhausted: ask once more for a plain answer.
    messages << { role: 'user', content: 'Stop calling tools and give your final answer to the user now, in plain text.' }
    { reply: present(@llm.chat(messages: messages)['content'].to_s), tool_calls: trace }
  end

  private

  def system_prompt(tools)
    docs = tools.map do |tool|
      fn = tool[:function]
      "- #{fn[:name]}: #{fn[:description].to_s.strip}\n  arguments (JSON Schema): #{JSON.generate(fn[:parameters])}"
    end.join("\n")

    <<~PROMPT
      #{BASE_PROMPT}
      You can call the following tools to look up real AgroPortal data:
      #{docs}

      To call a tool, write EXACTLY this and then stop immediately:
      #{TOOL_MARKER}{"tool": "<tool_name>", "arguments": { ... }}#{END_MARKER}
      Write nothing before or after it, and never fabricate the result — you will be given
      it in the next message. You may call tools several times, one at a time. When you have
      gathered enough information, reply with your final answer as normal text and do NOT
      write #{TOOL_MARKER}.
    PROMPT
  end

  # Returns { "tool" =>, "arguments" => } when `content` requests a tool, else nil.
  # Generation is stopped at END_MARKER, so a tool call arrives as "...[[TOOL]]{json}".
  def extract_tool_call(content)
    marker = content.to_s.rindex(TOOL_MARKER)
    return nil if marker.nil?

    obj = parse_json_object(content[(marker + TOOL_MARKER.length)..])
    return nil unless obj.is_a?(Hash)

    name = (obj['tool'] || obj['name']).to_s
    return nil unless @tool_names.include?(name)

    args = obj['arguments'] || obj['parameters'] || {}
    { 'tool' => name, 'arguments' => args.is_a?(Hash) ? args : {} }
  end

  # Parse the first balanced {...} JSON object found in the text.
  def parse_json_object(text)
    text = text.to_s.strip
    open_i = text.index('{')
    close_i = text.rindex('}')
    return nil if open_i.nil? || close_i.nil? || close_i <= open_i

    JSON.parse(text[open_i..close_i])
  rescue JSON::ParserError
    nil
  end

  def execute_tool(name, args)
    @mcp.call_tool(name, args)
  rescue McpClient::Error => e
    # Surface the failure to the model so it can recover or explain, rather than aborting.
    "Tool '#{name}' failed: #{e.message}"
  end

  def tool_result_message(name, result)
    <<~MSG
      Result of tool `#{name}`:
      #{truncate(result)}

      If you need more information, call another tool. Otherwise, reply with your final answer in plain text.
    MSG
  end

  # Keep only valid user/assistant turns coming from the browser; ignore anything else
  # (the system prompt and tool turns are managed server-side).
  def sanitize(conversation)
    Array(conversation).filter_map do |m|
      role = m['role'] || m[:role]
      content = m['content'] || m[:content]
      next unless %w[user assistant].include?(role) && content.to_s.strip != ''

      { role: role, content: content.to_s }
    end
  end

  def present(content)
    text = content.to_s.gsub(TOOL_MARKER, '').gsub(END_MARKER, '').strip
    text.empty? ? I18n.t('assistant.too_many_steps') : text
  end

  def truncate(text)
    text = text.to_s
    return text if text.length <= MAX_TOOL_RESULT_CHARS

    "#{text[0, MAX_TOOL_RESULT_CHARS]}\n…[truncated]"
  end
end
