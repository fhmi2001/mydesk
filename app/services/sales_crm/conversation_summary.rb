# Custom (MyDesk): a draft summary of a conversation for the employee to edit before anything is saved
# (CONVERSATION_SALES_PLAN.md, idea أ3): what the customer asked for, their objections, the next step, and an amount
# and close date only when the conversation states them. One call counted under the Sales monthly limit.
class SalesCrm::ConversationSummary
  MESSAGES = 50
  FIELDS = %w[summary objections next_step suggested_amount suggested_close_date].freeze
  SCHEMA = {
    name: 'sales_conversation_summary',
    schema: {
      type: 'object',
      properties: {
        summary: { type: 'string', description: 'What the customer asked for, in two or three sentences' },
        objections: { type: 'string', description: 'Their objections or hesitations, or empty' },
        next_step: { type: 'string', description: 'The next step for the team, in one sentence' },
        suggested_amount: { type: 'string', description: 'The deal amount only when the conversation states it, digits only, or empty' },
        suggested_close_date: { type: 'string', description: 'The expected close date (YYYY-MM-DD) only when the conversation states it, or empty' }
      },
      required: FIELDS,
      additionalProperties: false
    },
    strict: true
  }.freeze

  pattr_initialize [:account!, :conversation!]

  def perform
    fail!(:ai_not_configured) unless SmartAssistant::Config.configured?
    fail!(:ai_limit_reached, date: I18n.l(renews_on, format: :long)) if SmartAssistant::Usage.crm_limit_reached?(account)
    fail!(:conversation_empty) if transcript.blank?

    draft(SmartAssistant::LlmClient.new(account: account, kind: :crm_summary)
                                   .complete(instructions: instructions, messages: [{ role: :user, content: transcript }],
                                             schema: SCHEMA))
  end

  private

  def transcript
    @transcript ||= conversation.messages.where(message_type: %i[incoming outgoing], private: false).where.not(content: [nil, ''])
                                .reorder(id: :desc).limit(MESSAGES).to_a.reverse
                                .map { |message| "#{message.incoming? ? 'العميل' : 'الفريق'}: #{message.content}" }.join("\n")
  end

  def draft(result)
    { summary: text(result['summary']), objections: text(result['objections']), next_step: text(result['next_step']),
      suggested_amount: amount(result['suggested_amount']), suggested_close_date: date(result['suggested_close_date']) }
  end

  def text(value) = value.to_s.strip

  def amount(value)
    digits = SalesCrm::Normalize.digits(value.to_s).delete(',').strip
    digits.match?(/\A\d+(\.\d+)?\z/) && digits.to_f.positive? ? digits : nil
  end

  def date(value)
    Date.iso8601(value.to_s).iso8601
  rescue Date::Error
    nil
  end

  def renews_on = SalesCrm::Period.today.next_month.beginning_of_month

  def fail!(key, **args)
    raise SalesCrm::ValidationError, I18n.t("sales_crm.errors.#{key}", **args)
  end

  def instructions
    <<~PROMPT
      You help a sales team. Below is a customer conversation from "#{account.name}" (العميل is the customer, الفريق the team).
      Write a short note for the team, in Arabic: what the customer asked for, their objections, and the next step.
      Fill suggested_amount and suggested_close_date only when the conversation states them clearly; never guess
      them, leave them empty instead. Do not invent products, prices or dates.
    PROMPT
  end
end
