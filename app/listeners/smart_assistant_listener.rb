# Custom (MyDesk): starts the smart assistant's reply to each new customer message right away, and hands the
# conversation to an agent who assigns it to themselves. Subscribed to the sync dispatcher from
# config/initializers/smart_assistant.rb (it only enqueues or flips status), so Chatwoot's listener list stays untouched.
class SmartAssistantListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    return unless message.incoming? && !message.private?

    assistant = SmartAssistant.find_by(account_id: message.account_id)
    return unless assistant&.answers?(message.conversation)

    SmartAssistant::ReplyJob.perform_later(message.id)
  end

  # An agent taking the conversation ends the assistant's turn; seeing it in the list or opening it does not
  def assignee_changed(event)
    conversation = event.data[:conversation]
    return unless conversation.pending? && conversation.assignee_type == 'User' && conversation.assignee_id.present?

    assistant = SmartAssistant.find_by(account_id: conversation.account_id)
    conversation.bot_handoff! if assistant&.enabled? && assistant.handles_inbox?(conversation.inbox)
  end
end
