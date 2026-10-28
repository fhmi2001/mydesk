# Custom (MyDesk): the platform-wide smart assistant settings from Super Admin > Smart Assistant (or the
# SMART_ASSISTANT_* environment variables). One OpenAI key serves every account; each account's usage is
# capped by the monthly reply limit.
module SmartAssistant::Config
  DEFAULT_MONTHLY_REPLY_LIMIT = 1000

  module_function

  def api_key = GlobalConfigService.load('SMART_ASSISTANT_OPENAI_API_KEY', nil)

  def configured? = api_key.present?

  def model
    GlobalConfigService.load('SMART_ASSISTANT_MODEL', nil).presence || Llm::Models.default_model_for('assistant')
  end

  def embedding_model = LlmConstants::DEFAULT_EMBEDDING_MODEL

  def monthly_reply_limit
    GlobalConfigService.load('SMART_ASSISTANT_MONTHLY_REPLY_LIMIT', nil).presence&.to_i || DEFAULT_MONTHLY_REPLY_LIMIT
  end
end
