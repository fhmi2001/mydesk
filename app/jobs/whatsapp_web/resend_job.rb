# Custom (MyDesk): gives the WhatsApp Web gateway another go at a reply it failed to send. Each gateway failure
# note queues one resend; after MAX_RESENDS the reply is marked failed so the agent sees it and can retry it.
class WhatsappWeb::ResendJob < ApplicationJob
  queue_as :high

  MAX_RESENDS = 2
  # The gateway reconnects to WhatsApp within a few seconds of dropping
  RECONNECT_WAIT = 5.seconds

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return if message.nil? || message.source_id.present?

    key = "MYDESK::WHATSAPP_WEB::RESENDS::#{message.id}"
    resends = Redis::Alfred.incr(key)
    Redis::Alfred.expire(key, 1.hour.to_i)
    return message.update!(status: :failed, external_error: I18n.t('whatsapp_web.errors.not_sent')) if resends > MAX_RESENDS

    deliver(message)
  end

  private

  # The same payload Chatwoot's WebhookListener posts to an API inbox for a new message
  def deliver(message)
    channel = message.inbox.channel
    WebhookJob.perform_later(channel.webhook_url, message.webhook_data.merge(event: 'message_created'), :api_inbox_webhook,
                             secret: channel.secret, delivery_id: SecureRandom.uuid)
  end
end
