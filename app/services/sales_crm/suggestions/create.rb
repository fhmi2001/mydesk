# Custom (MyDesk): the one way a suggestion is made, whatever makes it (the assistant, an automation rule, the follow-up
# schedule, a stage change). A deal's suggestion is about its active conversation and its customer; a conversation's
# about that conversation's customer. Nothing is made while one of the same kind is pending there: the database keeps
# one too, and when two makers race the first one wins.
module SalesCrm::Suggestions::Create
  module_function

  # follow_up, won_message or lost_question, made by the schedule
  def for_deal(deal, kind)
    return if deal.account.crm_suggestions.pending.exists?(deal_id: deal.id, kind: kind)

    record(deal.account, kind: kind, origin: :schedule, deal: deal, conversation_id: deal.active_conversation_id,
                         contact_id: deal.contact_id)
  end

  # new_deal or note
  def for_conversation(conversation, kind, origin:, content: nil)
    account = conversation.account
    return if account.crm_suggestions.pending.exists?(conversation_id: conversation.id, kind: kind)

    record(account, kind: kind, origin: origin, conversation: conversation, contact_id: conversation.contact_id,
                    content: content)
  end

  def record(account, **attributes)
    # A savepoint, so losing the race leaves the caller's transaction usable
    account.transaction(requires_new: true) { account.crm_suggestions.create!(**attributes.compact) }
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
