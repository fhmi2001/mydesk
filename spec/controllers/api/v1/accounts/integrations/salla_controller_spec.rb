require 'rails_helper'

RSpec.describe 'Salla integration API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/integrations/salla" }

  before { allow(Salla::Config).to receive_messages(client_id: 'cid', client_secret: 'csecret') }

  it 'gives the Salla approval link with a state for this account' do
    get "#{base}/auth", headers: admin.create_new_auth_token, as: :json

    url = URI.parse(response.parsed_body['redirect_url'])
    query = Rack::Utils.parse_query(url.query)
    expect(url.to_s).to start_with(Salla::Config::AUTHORIZE_URL)
    expect(query).to include('client_id' => 'cid', 'response_type' => 'code', 'scope' => 'offline_access')
    expect(Salla::OauthClient.account_id_from(query['state'])).to eq(account.id)
  end

  it 'explains when the MyDesk Salla app is not configured' do
    allow(Salla::Config).to receive(:client_id).and_return(nil)

    get "#{base}/auth", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects agents' do
    get "#{base}/auth", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'lists the latest events of the store' do
    create_event = ->(event) { SallaEvent.create!(account: account, merchant_id: '1', event: event, order_id: '9') }
    create_event.call('order.created')
    create_event.call('order.status.updated')

    get "#{base}/events", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['payload'].pluck('event')).to eq(%w[order.status.updated order.created])
  end

  it 'disconnects the store' do
    create(:integrations_hook, app_id: 'salla', account: account, reference_id: '1')

    delete base, headers: admin.create_new_auth_token, as: :json

    expect(account.hooks.where(app_id: 'salla')).to be_empty
  end
end
