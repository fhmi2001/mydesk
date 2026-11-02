# Custom (MyDesk): the deal is followed in another conversation of the same customer from now on (decision ح,
# CONVERSATION_SALES_PLAN.md): the «اربطها» bar or the deal page. Its origin conversation never changes.
class SalesCrm::Deals::LinkConversation < SalesCrm::BaseService
  def perform(deal, conversation_display_id)
    conversation = account.conversations.find_by(display_id: conversation_display_id)
    fail!(:conversation_of_another_contact) unless conversation && deal.contact_id && conversation.contact_id == deal.contact_id
    return deal if deal.active_conversation_id == conversation.id

    deal.update!(active_conversation: conversation)
    log(deal, 'conversation_linked', conversation_id: conversation.id, display_id: conversation.display_id)
    deal
  end
end
