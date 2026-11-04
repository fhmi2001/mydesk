# Custom (MyDesk): the draft of a follow-up, a thank-you on a win or a short "why not?" on a loss
# (CONVERSATION_SALES_PLAN.md), written only when the employee asks and kept on the suggestion. The employee sends it themselves; the
# draft never names the deal's amount, probability or stage, nor any price, discount or date the conversation did not.
class SalesCrm::MessageDraft
  include SalesCrm::AiRequest

  MESSAGES = 20
  USAGE_KIND = { 'follow_up' => :crm_followup, 'won_message' => :crm_message, 'lost_question' => :crm_message }.freeze
  PURPOSE = {
    'follow_up' => 'a gentle follow-up to a customer who has not replied for a few days, inviting them to continue',
    'won_message' => 'a short thank-you to a customer who has just decided to buy',
    'lost_question' => 'a short, polite question asking what stopped the customer from going ahead, with no pressure'
  }.freeze
  SCHEMA = {
    name: 'sales_message_draft',
    schema: { type: 'object', properties: { message: { type: 'string', description: 'The message to the customer' } },
              required: %w[message], additionalProperties: false },
    strict: true
  }.freeze

  pattr_initialize [:account!, :suggestion!]

  def perform
    ensure_ai_available!(account)
    result = with_provider_errors do
      SmartAssistant::LlmClient.new(account: account, kind: USAGE_KIND.fetch(suggestion.kind))
                               .complete(instructions: instructions, messages: [{ role: :user, content: transcript }], schema: SCHEMA)
    end
    draft = Hash(result)['message'].to_s.strip
    suggestion.update!(content: suggestion.content.merge('draft' => draft))
    draft
  end

  private

  def conversation = suggestion.deal&.active_conversation || suggestion.conversation

  def transcript
    transcript_of(conversation, MESSAGES).presence || '(no messages yet)'
  end

  def instructions
    <<~PROMPT
      You write for a sales team of "#{account.name}". Draft #{PURPOSE.fetch(suggestion.kind)}.
      It is about "#{suggestion.deal&.title}" (stage: #{suggestion.deal&.stage&.name}). The conversation so far follows
      (العميل is the customer, الفريق the team).
      Rules:
      - Write in the customer's language and dialect, short and polite, ready to send as one chat message.
      - Do not mention prices, discounts, delivery times or dates that the conversation did not state.
      - Never mention the deal's internal amount, probability, stage or pipeline.
    PROMPT
  end
end
