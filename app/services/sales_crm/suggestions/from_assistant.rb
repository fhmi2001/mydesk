# Custom (MyDesk): the smart assistant saw a clear intent to buy in a conversation (CONVERSATION_SALES_PLAN.md, أ2).
# Leaves a pending «صفقة جديدة» suggestion for the employee to accept or dismiss; never a deal. A conversation keeps
# its first pending suggestion, and an account without the Sales section gets none.
module SalesCrm::Suggestions::FromAssistant
  module_function

  def call(conversation, lead)
    account = conversation.account
    return unless account.feature_enabled?('sales_crm')
    return if account.crm_suggestions.pending.new_deal.exists?(conversation_id: conversation.id)

    account.crm_suggestions.create!(conversation: conversation, contact_id: conversation.contact_id, kind: :new_deal,
                                    origin: :assistant, content: lead)
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
