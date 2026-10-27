require 'rails_helper'

RSpec.describe 'Salla OAuth callback', type: :request do
  let(:account) { create(:account) }
  let(:state) { Salla::OauthClient.state_for(account.id) }
  let(:connect_service) { instance_double(Salla::ConnectService, perform: true) }

  before do
    allow(Salla::Config).to receive_messages(client_id: 'cid', client_secret: 'csecret')
    allow(Salla::ConnectService).to receive(:new).and_return(connect_service)
  end

  it 'connects the store of the account named in the state' do
    get '/salla/callback', params: { code: 'the-code', state: state }

    expect(Salla::ConnectService).to have_received(:new).with(account: account, code: 'the-code')
    expect(response).to redirect_to(Salla::Config.integration_url(account.id, salla: 'connected'))
  end

  it 'rejects a forged or expired state' do
    forged = JWT.encode({ sub: account.id, exp: 1.minute.from_now.to_i }, 'other-secret', 'HS256')

    get '/salla/callback', params: { code: 'the-code', state: forged }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(Salla::ConnectService).not_to have_received(:new)
  end

  it 'reports a refusal back to the settings page' do
    get '/salla/callback', params: { error: 'access_denied', state: state }

    expect(response).to redirect_to(Salla::Config.integration_url(account.id, salla: 'denied'))
  end

  it 'reports a store already connected elsewhere' do
    allow(connect_service).to receive(:perform).and_raise(Salla::ConnectService::StoreTakenError)

    get '/salla/callback', params: { code: 'the-code', state: state }

    expect(response).to redirect_to(Salla::Config.integration_url(account.id, salla: 'store_taken'))
  end
end
