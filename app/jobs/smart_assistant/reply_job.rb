# Custom (MyDesk): answers a customer's message as the account's smart assistant. The team takes over only when
# the assistant hands over (the reply limit, a customer asking for a person, an answer it cannot give) and the
# conversation is then assigned to an agent, or when an agent assigns it to themselves (SmartAssistantListener).
# Viewing a conversation never takes it from the assistant.
class SmartAssistant::ReplyJob < ApplicationJob
  queue_as :high

  HISTORY_LIMIT = 20
  ATTEMPTS = 3

  # A failed reply is tried again; only when every try fails does the team take over, so the customer is not
  # left waiting on a silent assistant
  retry_on StandardError, wait: 2.seconds, attempts: ATTEMPTS do |job, error|
    message = Message.find_by(id: job.arguments.first)
    next unless message

    ChatwootExceptionTracker.new(error, account: message.account).capture_exception
    assistant = SmartAssistant.find_by(account_id: message.account_id)
    job.send(:handoff, assistant, message.conversation) if assistant&.answers?(message.conversation)
  end

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    conversation = message.conversation
    assistant = SmartAssistant.find_by(account_id: message.account_id)
    return unless assistant&.answers?(conversation)
    # A customer who sends several messages in a row gets one reply, from the job of the latest one
    return if newer_customer_message?(conversation, message)
    # Images, voice notes and files are for the team to look at
    return handoff(assistant, conversation) if message.content.blank?

    reply_or_handoff(assistant, conversation, message)
  end

  private

  def reply_or_handoff(assistant, conversation, message)
    return handoff(assistant, conversation) if skip_reply?(assistant, conversation)
    return handoff(assistant, conversation, assistant.handoff_message.presence) if reply_limit_reached?(assistant, conversation)

    result = SmartAssistant::Responder.new(assistant: assistant, messages: history(conversation)).perform
    # The customer wrote again while this reply was written: the newer job answers everything at once
    return if newer_customer_message?(conversation, message) || !assistant.reload.answers?(conversation.reload)

    send_reply(assistant, conversation, result[:reply]) if result[:reply].present?
    handoff(assistant, conversation) if result[:handoff]
  end

  # During working hours (in outside_working_hours mode) or past the monthly quota the team answers instead
  def skip_reply?(assistant, conversation)
    return true if assistant.reply_mode == 'outside_working_hours' && conversation.inbox.working_now?

    assistant.quota_reached?
  end

  def reply_limit_reached?(assistant, conversation)
    conversation.messages.where(sender: assistant.agent_bot).count >= assistant.max_replies
  end

  # Opens the conversation for the team and gives it to an agent. Inboxes with auto assignment pick the agent
  # themselves when the conversation opens; the others get an online inbox member here.
  def handoff(assistant, conversation, message = nil)
    send_reply(assistant, conversation, message) if message
    conversation.bot_handoff!
    return if conversation.assignee_id.present? || conversation.inbox.enable_auto_assignment?

    AutoAssignment::AgentAssignmentService.new(conversation: conversation,
                                               allowed_agent_ids: conversation.inbox.member_ids_with_assignment_capacity).perform
  end

  def newer_customer_message?(conversation, message)
    conversation.messages.incoming.exists?(['id > ?', message.id])
  end

  # Oldest first and ending with the customer's latest message
  def history(conversation)
    messages = conversation.messages.where(message_type: %i[incoming outgoing], private: false).where.not(content: [nil, ''])
                           .reorder(id: :desc).limit(HISTORY_LIMIT).to_a.reverse
                           .map { |message| { role: message.incoming? ? :user : :assistant, content: message.content } }
    messages.pop while messages.last && messages.last[:role] != :user
    messages
  end

  def send_reply(assistant, conversation, content)
    conversation.messages.create!(account: conversation.account, inbox: conversation.inbox, message_type: :outgoing,
                                  sender: assistant.agent_bot, content: content)
  end
end
