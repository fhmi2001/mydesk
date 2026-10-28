# Custom (MyDesk): the smart assistant's calls to OpenAI through ruby_llm, in a context of its own so the
# platform key never mixes with Captain's global configuration. Every call is recorded as a
# SmartAssistant::Usage of the account, with its tokens and its cost from the model registry prices.
class SmartAssistant::LlmClient
  EMBEDDING_BATCH_SIZE = 64
  FEATURE = 'assistant'.freeze
  # Connections to OpenAI drop now and then (SSL EOF, resets); a quick second try usually goes through
  NETWORK_ERRORS = [Faraday::SSLError, Faraday::ConnectionFailed, Faraday::TimeoutError].freeze
  NETWORK_RETRIES = 2

  # kind is the SmartAssistant::Usage kind the calls are counted under
  pattr_initialize [:account!, :kind!]

  def embed(texts)
    with_context do |context|
      texts.each_slice(EMBEDDING_BATCH_SIZE).flat_map do |batch|
        embedding = context.embed(batch, model: SmartAssistant::Config.embedding_model)
        record(SmartAssistant::Config.embedding_model, embedding)
        embedding.vectors
      end
    end
  end

  def embed_one(text)
    embed([text]).first
  end

  # Returns the parsed JSON object that matches schema
  def complete(instructions:, messages:, schema:)
    with_context do |context|
      chat = build_chat(context, instructions)
      chat.with_schema(schema)
      messages[0...-1].each { |message| chat.add_message(role: message[:role], content: message[:content]) }
      response = chat.ask(messages.last[:content])
      record(SmartAssistant::Config.model, response)
      response.parsed
    end
  end

  # Reads the text out of a PDF the merchant uploaded
  def extract_text(path, prompt)
    with_context do |context|
      response = build_chat(context, nil).ask(prompt, with: path)
      record(SmartAssistant::Config.model, response)
      response.content
    end
  end

  private

  def with_context(&)
    attempts = 0
    begin
      Llm::Config.with_api_key(SmartAssistant::Config.api_key, &)
    rescue *NETWORK_ERRORS
      attempts += 1
      retry if attempts <= NETWORK_RETRIES
      raise
    end
  end

  def build_chat(context, instructions)
    model = SmartAssistant::Config.model
    options = Captain::ResponsesConfig.options(model: model, temperature: nil, feature: FEATURE)
    chat = context.chat(model: model, **options.slice(:protocol))
    chat.with_thinking(**options[:thinking]) if options[:thinking]
    chat.with_instructions(instructions) if instructions
    chat
  end

  # result is a ruby_llm message or embedding; cost stays empty when the registry has no price for the model
  def record(model, result)
    tokens = result.tokens
    SmartAssistant::Usage.create!(account: account, kind: kind, model: model, input_tokens: tokens.input.to_i,
                                  output_tokens: tokens.output.to_i, cached_tokens: tokens.cache_read.to_i,
                                  cost: result.cost.total)
  end
end
