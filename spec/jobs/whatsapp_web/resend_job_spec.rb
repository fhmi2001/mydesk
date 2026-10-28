require 'rails_helper'

RSpec.describe WhatsappWeb::ResendJob do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_api, account: account, webhook_url: 'http://evolution-api:8080/chatwoot/webhook/bajaba') }
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox) }
  let(:reply) { create(:message, conversation: conversation, account: account, inbox: channel.inbox, message_type: :outgoing) }

  before { Redis::Alfred.delete("MYDESK::WHATSAPP_WEB::RESENDS::#{reply.id}") }

  it 'posts the reply to the gateway again' do
    expect { described_class.perform_now(reply.id) }
      .to have_enqueued_job(WebhookJob).with(channel.webhook_url, hash_including(id: reply.id, event: 'message_created'), :api_inbox_webhook,
                                             secret: channel.secret, delivery_id: anything)
  end

  it 'marks the reply failed once the resends are used up' do
    (described_class::MAX_RESENDS + 1).times { described_class.perform_now(reply.id) }

    expect(reply.reload).to be_failed
    expect(reply.external_error).to be_present
  end

  it 'stops once the reply has reached WhatsApp' do
    reply.update!(source_id: 'WAID:3EB0')

    expect { described_class.perform_now(reply.id) }.not_to have_enqueued_job(WebhookJob)
  end
end
