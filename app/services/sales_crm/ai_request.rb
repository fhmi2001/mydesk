# Custom (MyDesk): what the Sales section's AI drafts share (CONVERSATION_SALES_PLAN.md): the checks before a call
# (the assistant set up, the Sales monthly limit not reached) and a conversation's public messages as one transcript.
module SalesCrm::AiRequest
  private

  def ensure_ai_available!(account)
    fail_ai!(:ai_not_configured) unless SmartAssistant::Config.configured?
    return unless SmartAssistant::Usage.crm_limit_reached?(account)

    fail_ai!(:ai_limit_reached, date: I18n.l(SalesCrm::Period.today.next_month.beginning_of_month, format: :long))
  end

  # The latest `limit` public messages, oldest first: «العميل: ...» / «الفريق: ...»
  def transcript_of(conversation, limit)
    return '' unless conversation

    conversation.messages.where(message_type: %i[incoming outgoing], private: false).where.not(content: [nil, ''])
                .reorder(id: :desc).limit(limit).to_a.reverse
                .map { |message| "#{message.incoming? ? 'العميل' : 'الفريق'}: #{message.content}" }.join("\n")
  end

  def fail_ai!(key, **args)
    raise SalesCrm::ValidationError, I18n.t("sales_crm.errors.#{key}", **args)
  end
end
