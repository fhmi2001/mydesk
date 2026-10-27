require 'rails_helper'

describe Salla::ConnectService do
  let(:account) { create(:account) }
  let(:token_body) do
    { access_token: 'access-1', refresh_token: 'refresh-1', expires_in: 1_209_600, scope: 'offline_access', token_type: 'bearer' }
  end
  let(:user_info_body) do
    { status: 200, success: true,
      data: { id: 1, name: 'Owner', merchant: { id: 987_654, username: 'my-store', name: 'متجري', domain: 'https://salla.sa/my-store' } } }
  end

  before do
    allow(Salla::Config).to receive_messages(client_id: 'cid', client_secret: 'csecret')
    stub_request(:post, Salla::Config::TOKEN_URL)
      .with(body: hash_including('grant_type' => 'authorization_code', 'code' => 'the-code', 'client_id' => 'cid'))
      .to_return(status: 200, body: token_body.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, Salla::Config::USER_INFO_URL)
      .with(headers: { 'Authorization' => 'Bearer access-1' })
      .to_return(status: 200, body: user_info_body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  it 'stores the store and its tokens on the account Salla hook' do
    hook = described_class.new(account: account, code: 'the-code').perform

    expect(hook).to have_attributes(app_id: 'salla', reference_id: '987654', access_token: 'access-1', status: 'enabled')
    expect(hook.settings).to include('refresh_token' => 'refresh-1', 'store_name' => 'متجري', 'store_domain' => 'https://salla.sa/my-store')
    expect(Time.zone.parse(hook.settings['expires_at'])).to be_within(1.minute).of(14.days.from_now)
  end

  it 'reconnecting updates the same hook' do
    described_class.new(account: account, code: 'the-code').perform

    expect { described_class.new(account: account, code: 'the-code').perform }.not_to change(Integrations::Hook, :count)
  end

  it 'refuses a store that another account already connected' do
    create(:integrations_hook, app_id: 'salla', account: create(:account), reference_id: '987654')

    expect { described_class.new(account: account, code: 'the-code').perform }.to raise_error(described_class::StoreTakenError)
  end

  it 'raises when Salla rejects the code' do
    stub_request(:post, Salla::Config::TOKEN_URL)
      .to_return(status: 400, body: { error: 'invalid_grant' }.to_json, headers: { 'Content-Type' => 'application/json' })

    expect { described_class.new(account: account, code: 'the-code').perform }.to raise_error(Salla::OauthClient::Error, 'invalid_grant')
  end
end
