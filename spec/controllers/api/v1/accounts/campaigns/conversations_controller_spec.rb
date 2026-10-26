require 'rails_helper'

RSpec.describe 'Campaign conversations API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:web_widget) { create(:channel_widget, account: account) }
  let(:campaign) { create(:campaign, account: account, inbox: web_widget.inbox, trigger_rules: { url: 'https://example.com' }) }
  let(:path) { "/api/v1/accounts/#{account.id}/campaigns/#{campaign.display_id}/conversations" }

  it 'rejects agents' do
    get path, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'lists the conversations the campaign started, newest first' do
    contact = create(:contact, account: account, name: 'Visitor')
    older = create(:conversation, account: account, inbox: web_widget.inbox, contact: contact, campaign: campaign, created_at: 2.days.ago)
    newer = create(:conversation, account: account, inbox: web_widget.inbox, campaign: campaign)
    create(:conversation, account: account, inbox: web_widget.inbox)

    get path, headers: admin.create_new_auth_token, as: :json

    body = response.parsed_body
    expect(body['meta']['count']).to eq(2)
    expect(body['payload'].pluck('id')).to eq([newer.display_id, older.display_id])
    expect(body['payload'].last['contact']['name']).to eq('Visitor')
  end

  it 'counts the conversations on the campaign itself' do
    create(:conversation, account: account, inbox: web_widget.inbox, campaign: campaign)

    get "/api/v1/accounts/#{account.id}/campaigns/#{campaign.display_id}", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body).to include('conversations_count' => 1)
    expect(response.parsed_body['last_conversation_at']).to be_present
  end
end
