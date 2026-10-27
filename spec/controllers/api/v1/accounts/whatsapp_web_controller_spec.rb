require 'rails_helper'

RSpec.describe 'WhatsApp Web (QR) channel API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:gateway) { 'http://gateway.test' }
  let(:base_path) { "/api/v1/accounts/#{account.id}/whatsapp_web" }
  let(:instance_name) { "mydesk-#{account.id}-abcd1234" }

  before do
    allow(WhatsappWeb::Config).to receive_messages(api_url: gateway, api_key: 'test-key', chatwoot_url: 'http://rails:3000')
  end

  def create_gateway_inbox(name)
    channel = Channel::Api.create!(account: account, webhook_url: "#{gateway}/chatwoot/webhook/#{name}")
    create(:inbox, account: account, channel: channel, name: 'Store WhatsApp')
  end

  describe 'GET /whatsapp_web' do
    it 'tells admins whether the gateway is set up' do
      get base_path, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq('configured' => true)
    end

    it 'is admin only' do
      get base_path, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /whatsapp_web' do
    before { allow(SecureRandom).to receive(:hex).and_call_original }

    it 'creates the inbox, then the number on the gateway pointed at it' do
      allow(SecureRandom).to receive(:hex).with(4).and_return('abcd1234')
      request_stub = stub_request(:post, "#{gateway}/instance/create")
                     .with(headers: { 'apikey' => 'test-key' },
                           body: hash_including('instanceName' => instance_name, 'chatwootAccountId' => account.id.to_s,
                                                'chatwootNameInbox' => 'Store WhatsApp', 'autoCreate' => false,
                                                'chatwootSignMsg' => false))
                     .to_return(status: 201, body: { instance: { instanceName: instance_name } }.to_json,
                                headers: { 'Content-Type' => 'application/json' })
      receipts_stub = stub_request(:post, "#{gateway}/webhook/set/#{instance_name}")
                      .with(body: hash_including('webhook' => hash_including(
                        'url' => "http://rails:3000/webhooks/whatsapp_web/#{instance_name}",
                        'events' => ['MESSAGES_UPDATE'],
                        'headers' => { 'X-MyDesk-Token' => WhatsappWeb::Config.receipts_token_for(instance_name) }
                      )))
                      .to_return(status: 201, body: '{}', headers: { 'Content-Type' => 'application/json' })

      post base_path, params: { name: ' Store WhatsApp ' }, headers: admin.create_new_auth_token, as: :json

      expect(request_stub).to have_been_requested
      expect(receipts_stub).to have_been_requested
      expect(response).to have_http_status(:success)
      inbox = account.inboxes.find(response.parsed_body['id'])
      expect(inbox.name).to eq('Store WhatsApp')
      expect(inbox.channel.webhook_url).to eq("#{gateway}/chatwoot/webhook/#{instance_name}")
    end

    it 'rejects a name already used in the account, since the gateway finds the inbox by name' do
      create(:inbox, account: account, name: 'Store WhatsApp')

      post base_path, params: { name: 'Store WhatsApp' }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('name_taken')
    end

    it 'removes the inbox again when the gateway fails' do
      stub_request(:post, "#{gateway}/instance/create").to_return(status: 500, body: { error: 'gateway down' }.to_json,
                                                                  headers: { 'Content-Type' => 'application/json' })

      expect do
        post base_path, params: { name: 'Store WhatsApp' }, headers: admin.create_new_auth_token, as: :json
      end.not_to change(Inbox, :count)

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body['error']).to eq('gateway down')
    end

    it 'refuses when the gateway is not configured' do
      allow(WhatsappWeb::Config).to receive(:configured?).and_return(false)

      post base_path, params: { name: 'Store WhatsApp' }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /whatsapp_web/inboxes/:inbox_id/connection' do
    let!(:inbox) { create_gateway_inbox(instance_name) }

    it 'returns the QR code while waiting for the phone' do
      stub_request(:get, "#{gateway}/instance/connectionState/#{instance_name}")
        .to_return(status: 200, body: { instance: { state: 'connecting' } }.to_json, headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, "#{gateway}/instance/connect/#{instance_name}")
        .to_return(status: 200, body: { base64: 'data:image/png;base64,QR' }.to_json, headers: { 'Content-Type' => 'application/json' })

      get "#{base_path}/inboxes/#{inbox.id}/connection", headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body).to eq('state' => 'connecting', 'qr_code' => 'data:image/png;base64,QR')
    end

    it 'skips the QR once the phone is linked' do
      stub_request(:get, "#{gateway}/instance/connectionState/#{instance_name}")
        .to_return(status: 200, body: { instance: { state: 'open' } }.to_json, headers: { 'Content-Type' => 'application/json' })

      get "#{base_path}/inboxes/#{inbox.id}/connection", headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body).to eq('state' => 'open', 'qr_code' => nil)
    end

    it 'rejects inboxes that are not WhatsApp Web' do
      other = create(:inbox, account: account)

      get "#{base_path}/inboxes/#{other.id}/connection", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /whatsapp_web/inboxes/:inbox_id/connection' do
    it 'unlinks the phone on the gateway' do
      inbox = create_gateway_inbox(instance_name)
      logout = stub_request(:delete, "#{gateway}/instance/logout/#{instance_name}").to_return(status: 200, body: '{}')

      delete "#{base_path}/inboxes/#{inbox.id}/connection", headers: admin.create_new_auth_token, as: :json

      expect(logout).to have_been_requested
      expect(response).to have_http_status(:success)
    end
  end
end
