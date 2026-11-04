# Custom (MyDesk): an employee's reply to a customer counts on the deal followed in that conversation
# (docs/mydesk/CONVERSATION_SALES_PLAN.md): it moves the deal's last_message_at and last_touch_at, never its
# last_activity_at, and writes no activity line. A reply in a new conversation of a customer with one open deal,
# sent by that deal's owner, makes it the deal's active conversation. Subscribed to the async dispatcher from
# config/initializers/sales_crm.rb, so Chatwoot's listener list stays untouched.
class SalesCrm::MessageListener < BaseListener
  THROTTLE = 1.minute

  def message_created(event)
    message = event.data[:message]
    return unless counts?(message)

    deals = followed_in(message.conversation)
    if deals.exists?
      record_reply(deals, message.created_at)
    else
      follow_here(message)
    end
  end

  private

  # Outgoing, public and written by an employee: not the bot, not an automation rule, not a note
  def counts?(message)
    message.outgoing? && !message.private? && message.sender_type == 'User' &&
      message.content_attributes&.dig('automation_rule_id').blank? &&
      message.account.feature_enabled?('sales_crm')
  end

  def followed_in(conversation)
    conversation.account.crm_deals.kept.open.where(active_conversation_id: conversation.id)
  end

  def record_reply(deals, at)
    deals.where(last_message_at: nil).or(deals.where(last_message_at: ...(at - THROTTLE))).update_all(last_message_at: at) # rubocop:disable Rails/SkipsModelValidations
    deals.where(last_touch_at: nil).or(deals.where(last_touch_at: ...at)).update_all(last_touch_at: at) # rubocop:disable Rails/SkipsModelValidations
  end

  def follow_here(message)
    conversation = message.conversation
    return if conversation.contact_id.blank?

    open_deals = conversation.account.crm_deals.kept.open.where(contact_id: conversation.contact_id).limit(2).to_a
    deal = open_deals.first
    return unless open_deals.one? && deal.assignee_id == message.sender_id

    deal.update_columns(active_conversation_id: conversation.id) # rubocop:disable Rails/SkipsModelValidations
    SalesCrm::ActivityLog.record(deal: deal, kind: 'conversation_linked', user: nil,
                                 data: { conversation_id: conversation.id, display_id: conversation.display_id, automatic: true })
    record_reply(followed_in(conversation).where(id: deal.id), message.created_at)
  end
end
