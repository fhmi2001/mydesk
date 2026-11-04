# Custom (MyDesk): the smart assistant saw a clear intent to buy in a conversation (CONVERSATION_SALES_PLAN.md).
# Leaves a pending «صفقة جديدة» suggestion for the employee to accept or dismiss; never a deal. A conversation keeps
# its first pending suggestion, and an account without the Sales section gets none.
module SalesCrm::Suggestions::FromAssistant
  module_function

  def call(conversation, lead)
    return unless conversation.account.feature_enabled?('sales_crm')

    SalesCrm::Suggestions::Create.for_conversation(conversation, :new_deal, origin: :assistant, content: lead)
  end
end
