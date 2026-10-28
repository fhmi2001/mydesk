require 'rails_helper'

# The listener is subscribed to the dispatcher, so creating the gateway note runs it like in production
RSpec.describe WhatsappWebSendFailureListener do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_api, account: account, webhook_url: 'http://evolution-api:8080/chatwoot/webhook/bajaba') }
  let(:inbox) { channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:reply) { create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, content: 'البكج فيه 20 عبوة') }

  def create_note(content = '🚨 The message could not be sent. Please check your connection. _1006_')
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, private: true, content: content)
  end

  it 'removes the gateway note and resends the reply that did not go out' do
    note = nil
    expect { note = create_note }.to have_enqueued_job(WhatsappWeb::ResendJob).with(reply.id)
    expect(Message.exists?(note.id)).to be(false)
  end

  it 'leaves replies that reached WhatsApp alone' do
    reply.update!(source_id: 'WAID:3EB0')

    expect { create_note }.not_to have_enqueued_job(WhatsappWeb::ResendJob)
  end

  it 'ignores ordinary private notes' do
    note = nil
    expect { note = create_note('Customer called, call back tomorrow') }.not_to have_enqueued_job(WhatsappWeb::ResendJob)
    expect(Message.exists?(note.id)).to be(true)
  end
end
