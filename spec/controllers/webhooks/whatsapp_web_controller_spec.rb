require 'rails_helper'

RSpec.describe 'WhatsApp Web receipts webhook', type: :request do
  let(:account) { create(:account) }
  let(:gateway) { 'http://gateway.test' }
  let(:instance_name) { "mydesk-#{account.id}-abcd1234" }
  let(:channel) { Channel::Api.create!(account: account, webhook_url: "#{gateway}/chatwoot/webhook/#{instance_name}") }
  let(:inbox) { create(:inbox, account: account, channel: channel) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, source_id: 'WAID:3EB0ABC')
  end
  let(:token) { WhatsappWeb::Config.receipts_token_for(instance_name) }

  before do
    allow(WhatsappWeb::Config).to receive(:api_url).and_return(gateway)
  end

  def post_receipt(status, key_id: '3EB0ABC', from_me: true, headers: { 'X-MyDesk-Token' => token })
    body = { event: 'messages.update', instance: instance_name, apikey: 'instance-key',
             data: { keyId: key_id, fromMe: from_me, status: status, remoteJid: '966500000000@s.whatsapp.net' } }
    post "/webhooks/whatsapp_web/#{instance_name}", params: body.to_json,
                                                    headers: headers.merge('Content-Type' => 'application/json')
  end

  it 'marks the message delivered, then read' do
    post_receipt('DELIVERY_ACK')
    expect(message.reload.status).to eq('delivered')

    post_receipt('READ')
    expect(message.reload.status).to eq('read')
  end

  it 'never moves a status backwards' do
    message.update!(status: :read)

    post_receipt('DELIVERY_ACK')

    expect(message.reload.status).to eq('read')
  end

  it 'clears a timeout failure once WhatsApp confirms delivery' do
    message.update!(status: :failed, external_error: 'Net::ReadTimeout')

    post_receipt('DELIVERY_ACK')

    expect(message.reload).to have_attributes(status: 'delivered', external_error: nil)
  end

  it 'ignores receipts for messages the customer sent and unknown statuses' do
    post_receipt('READ', from_me: false)
    post_receipt('SERVER_ACK')

    expect(message.reload.status).to eq('sent')
  end

  it 'rejects requests without the number secret' do
    post_receipt('READ', headers: { 'X-MyDesk-Token' => 'wrong' })

    expect(response).to have_http_status(:unauthorized)
    expect(message.reload.status).to eq('sent')
  end

  it 'does not accept another number secret' do
    other_token = WhatsappWeb::Config.receipts_token_for('mydesk-999-other')

    post_receipt('READ', headers: { 'X-MyDesk-Token' => other_token })

    expect(response).to have_http_status(:unauthorized)
  end
end
