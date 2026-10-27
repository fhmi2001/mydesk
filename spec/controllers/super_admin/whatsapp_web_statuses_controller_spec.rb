require 'rails_helper'

RSpec.describe 'Super Admin WhatsApp Web gateway', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:account) { create(:account, name: 'Store One') }
  let(:gateway) { 'http://gateway.test' }
  let(:linked_name) { "mydesk-#{account.id}-aaaa1111" }
  let(:orphan_name) { 'mydesk-9-bbbb2222' }
  let(:json) { { 'Content-Type' => 'application/json' } }
  let(:scope) { 'super_admin.whatsapp_web' }

  before do
    allow(WhatsappWeb::Config).to receive_messages(api_url: gateway, api_key: 'test-key')
    channel = Channel::Api.create!(account: account, webhook_url: "#{gateway}/chatwoot/webhook/#{linked_name}")
    create(:inbox, account: account, channel: channel, name: 'Store WhatsApp')

    stub_request(:get, "#{gateway}/").to_return(status: 200, headers: json,
                                                body: { version: '2.3.7', whatsappWebVersion: '2.3000.1' }.to_json)
    stub_request(:get, "#{gateway}/instance/fetchInstances").to_return(status: 200, headers: json, body: [
      { name: linked_name, connectionStatus: 'open', ownerJid: '966500000001@s.whatsapp.net', profileName: 'Store One',
        createdAt: '2026-10-27T21:01:50.649Z', _count: { Message: 349 } },
      { name: orphan_name, connectionStatus: 'close', ownerJid: nil, createdAt: '2026-10-27T20:00:00Z', _count: { Message: 0 } }
    ].to_json)
    stub_request(:get, WhatsappWeb::ReleaseCheck::RELEASES_URL).to_return(status: 200, headers: json, body: [
      { tag_name: '2.4.0-rc2', prerelease: true, published_at: '2026-05-17T00:00:00Z', html_url: 'https://github.test/rc2' },
      { tag_name: '2.3.8', prerelease: false, published_at: '2026-06-01T00:00:00Z', html_url: 'https://github.test/238' },
      { tag_name: '2.3.7', prerelease: false, published_at: '2025-12-05T00:00:00Z', html_url: 'https://github.test/237' }
    ].to_json)
  end

  it 'requires a signed-in super admin' do
    get '/super_admin/whatsapp_web_status'

    expect(response).to have_http_status(:redirect)
  end

  context 'when signed in' do
    before { sign_in(super_admin, scope: :super_admin) }

    it 'shows the version, the stable update, the version in testing and every number' do
      get '/super_admin/whatsapp_web_status'

      expect(response).to have_http_status(:success)
      body = response.body
      expect(body).to include('2.3.7', '2.3000.1')
      expect(body).to include(CGI.escapeHTML(I18n.t("#{scope}.updates.available", version: '2.3.8')))
      expect(body).to include(CGI.escapeHTML(I18n.t("#{scope}.updates.upcoming", version: '2.4.0-rc2')))
      expect(body).to include('+966500000001', 'Store One', 'Store WhatsApp')
      expect(body).to include(CGI.escapeHTML(I18n.t("#{scope}.numbers.orphan")))
    end

    it 'warns about licence activation only for 2.4.0 and later, release candidates included' do
      get '/super_admin/whatsapp_web_status'

      expect(response.body).to include(CGI.escapeHTML(I18n.t("#{scope}.updates.upcoming_license").strip))
      expect(response.body).not_to include(CGI.escapeHTML(I18n.t("#{scope}.updates.license_warning")))
    end

    it 'still renders when the gateway is down' do
      stub_request(:get, "#{gateway}/").to_raise(Errno::ECONNREFUSED)

      get '/super_admin/whatsapp_web_status'

      expect(response).to have_http_status(:success)
      expect(response.body).to include(CGI.escapeHTML(I18n.t("#{scope}.health.failing")))
    end

    it 'checks GitHub again on request' do
      allow(WhatsappWeb::ReleaseCheck).to receive(:refresh!)

      post '/super_admin/whatsapp_web_status/refresh'

      expect(WhatsappWeb::ReleaseCheck).to have_received(:refresh!)
      expect(response).to redirect_to('/super_admin/whatsapp_web_status')
    end

    it 'removes a number whose inbox was deleted' do
      removal = stub_request(:delete, "#{gateway}/instance/delete/#{orphan_name}").to_return(status: 200, headers: json, body: '{}')

      delete '/super_admin/whatsapp_web_status/remove_number', params: { name: orphan_name }

      expect(removal).to have_been_requested
      expect(flash[:notice]).to eq(I18n.t("#{scope}.numbers.removed", name: orphan_name))
    end

    it 'keeps a number that still has an inbox' do
      removal = stub_request(:delete, "#{gateway}/instance/delete/#{linked_name}")

      delete '/super_admin/whatsapp_web_status/remove_number', params: { name: linked_name }

      expect(removal).not_to have_been_requested
      expect(flash[:alert]).to eq(I18n.t("#{scope}.numbers.still_linked"))
    end
  end
end
