# Custom (MyDesk): when the WhatsApp Web gateway (Evolution API) loses its WhatsApp connection mid-send, it does
# not retry; it posts a private "🚨 The message could not be sent… 1006" note into the conversation instead.
# This listener removes that note and resends the reply that did not go out, then marks it failed (with the
# usual retry button) if the gateway still cannot send it.
class WhatsappWebSendFailureListener < BaseListener
  GATEWAY_FAILURE_NOTE = /\A🚨/
  FAILED_REPLY_WINDOW = 2.minutes

  def message_created(event)
    note = event.data[:message]
    return unless gateway_failure_note?(note)

    reply = unsent_reply(note.conversation)
    note.destroy!
    WhatsappWeb::ResendJob.set(wait: WhatsappWeb::ResendJob::RECONNECT_WAIT).perform_later(reply.id) if reply
  end

  private

  def gateway_failure_note?(message)
    message.private? && message.outgoing? && message.content.to_s.match?(GATEWAY_FAILURE_NOTE) &&
      WhatsappWeb::Config::WEBHOOK_PATH.match?(message.inbox.channel.try(:webhook_url).to_s)
  end

  # The gateway gives a sent reply its WhatsApp id (source_id); the newest recent reply without one is the lost one
  def unsent_reply(conversation)
    conversation.messages.outgoing.where(private: false, source_id: nil)
                .where(created_at: FAILED_REPLY_WINDOW.ago..).where.not(status: :failed).reorder(id: :desc).first
  end
end
