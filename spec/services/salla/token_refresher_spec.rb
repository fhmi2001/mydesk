require 'rails_helper'

describe Salla::TokenRefresher do
  let!(:hook) do
    create(:integrations_hook, app_id: 'salla', reference_id: '111', access_token: 'old-access',
                               settings: { 'refresh_token' => 'old-refresh', 'expires_at' => 1.day.from_now.iso8601 })
  end

  before { allow(Salla::Config).to receive_messages(client_id: 'cid', client_secret: 'csecret') }

  it 'picks hooks that expire soon' do
    fresh = create(:integrations_hook, app_id: 'salla', reference_id: '222', account: create(:account),
                                       settings: { 'expires_at' => 10.days.from_now.iso8601 })

    expect(described_class.due_hooks).to include(hook)
    expect(described_class.due_hooks).not_to include(fresh)
  end

  it 'stores the renewed tokens' do
    stub_request(:post, Salla::Config::TOKEN_URL)
      .with(body: hash_including('grant_type' => 'refresh_token', 'refresh_token' => 'old-refresh'))
      .to_return(status: 200, body: { access_token: 'new-access', refresh_token: 'new-refresh', expires_in: 1_209_600 }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    described_class.new(hook: hook).perform

    expect(hook.reload).to have_attributes(access_token: 'new-access', status: 'enabled')
    expect(hook.settings['refresh_token']).to eq('new-refresh')
  end

  it 'disables the connection when Salla refuses the refresh token' do
    stub_request(:post, Salla::Config::TOKEN_URL)
      .to_return(status: 401, body: { error: 'invalid_grant' }.to_json, headers: { 'Content-Type' => 'application/json' })

    described_class.new(hook: hook).perform

    expect(hook.reload).to have_attributes(status: 'disabled')
    expect(hook.settings['disabled_reason']).to eq('token_refresh_failed')
  end
end
