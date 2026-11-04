# Custom (MyDesk): what the Sales section knows about one conversation, for the deal form and the side panel
require 'rails_helper'

RSpec.describe 'Sales CRM conversation API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account) }
  let(:whatsapp) { SalesCrm::ListItem.create!(account: account, list: 'lead_source', name: 'واتساب') }
  let(:path) { "/api/v1/accounts/#{account.id}/crm/conversations/#{conversation.display_id}" }

  # An agent opens only conversations of their inboxes (ConversationPolicy), as everywhere else in the dashboard
  def member_of_inbox(user, *conversations) = conversations.each { |c| create(:inbox_member, user: user, inbox: c.inbox) } && user

  before do
    account.enable_features!('sales_crm')
    member_of_inbox(agent, conversation)
  end

  it "gives the lead source mapped to the conversation's inbox" do
    account.update!(crm_channel_sources: { conversation.inbox_id.to_s => whatsapp.id })
    get path, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('lead_source_id' => whatsapp.id)
  end

  it 'gives no lead source for an inbox mapped to nothing' do
    get path, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('lead_source_id' => nil)
  end

  it 'says whether the summary can be asked for' do
    allow(SmartAssistant::Config).to receive(:configured?).and_return(false)
    get path, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('ai_available' => false)
  end

  describe 'suggestions' do
    let(:admin) { create(:user, account: account, role: :administrator) }
    let!(:suggestion) do
      SalesCrm::Suggestion.create!(account: account, conversation: conversation, kind: :new_deal, content: { summary: '500 كرتون' })
    end

    it 'lists the pending ones the user may see' do
      get path, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['suggestions']).to contain_exactly(
        include('id' => suggestion.id, 'kind' => 'new_deal', 'content' => { 'summary' => '500 كرتون' })
      )
    end

    it 'hides them from an employee the conversation is not assigned to' do
      get path, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['suggestions']).to eq([])
    end

    it 'lets the employee handling the conversation dismiss one, and nobody else' do
      post "/api/v1/accounts/#{account.id}/crm/suggestions/#{suggestion.id}/dismiss", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)

      conversation.update!(assignee: agent)
      post "/api/v1/accounts/#{account.id}/crm/suggestions/#{suggestion.id}/dismiss", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
      expect(suggestion.reload).to have_attributes(status: 'dismissed', decided_by_id: agent.id)
    end
  end

  describe 'linking a new conversation to a deal (decision ح)' do
    let(:contact) { create(:contact, account: account) }
    let(:old_conversation) { create(:conversation, account: account, contact: contact) }
    let(:conversation) { create(:conversation, account: account, contact: contact) }
    let!(:deal) { create(:crm_deal, account: account, contact: contact, assignee: agent, conversation: old_conversation) }
    let(:link_path) { "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}/link_conversation" }

    it "offers the customer's open deals followed elsewhere to their owner" do
      get path, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['linkable_deals']).to contain_exactly(
        include('id' => deal.id, 'title' => deal.title, 'active_conversation_display_id' => old_conversation.display_id)
      )
    end

    it "offers nothing to an employee who does not own the deal, nor for the deal's own conversation" do
      colleague = member_of_inbox(create(:user, account: account, role: :agent), conversation)
      get path, headers: colleague.create_new_auth_token, as: :json
      expect(response.parsed_body['linkable_deals']).to eq([])

      member_of_inbox(agent, old_conversation)

      get "/api/v1/accounts/#{account.id}/crm/conversations/#{old_conversation.display_id}", headers: agent.create_new_auth_token,
                                                                                             as: :json
      expect(response.parsed_body['linkable_deals']).to eq([])
    end

    it 'follows the deal in the conversation from now on, keeping its origin, and logs it' do
      post link_path, params: { conversation_id: conversation.display_id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(deal.reload).to have_attributes(active_conversation_id: conversation.id, conversation_id: old_conversation.id)
      expect(deal.activities.first).to have_attributes(kind: 'conversation_linked', user_id: agent.id)
    end

    it "refuses another customer's conversation, and another employee's deal" do
      stranger = create(:conversation, account: account)
      post link_path, params: { conversation_id: stranger.display_id }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      post link_path, params: { conversation_id: conversation.display_id },
                      headers: create(:user, account: account, role: :agent).create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
      expect(deal.reload.active_conversation_id).to eq(old_conversation.id)
    end
  end

  describe 'summary' do
    it 'returns the draft for the employee to edit' do
      draft = { summary: 'x', objections: '', next_step: '', suggested_amount: nil, suggested_close_date: nil }
      allow(SalesCrm::ConversationSummary).to receive(:new).and_return(instance_double(SalesCrm::ConversationSummary, perform: draft))

      post "#{path}/summary", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('summary' => 'x', 'suggested_amount' => nil)
    end

    it 'explains why there is none' do
      allow(SmartAssistant::Config).to receive(:configured?).and_return(false)
      post "#{path}/summary", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to eq(I18n.t('sales_crm.errors.ai_not_configured'))
    end
  end

  it 'refuses a conversation outside the inboxes of the agent' do
    outside = create(:conversation, account: account)
    get "/api/v1/accounts/#{account.id}/crm/conversations/#{outside.display_id}", headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "does not find another account's conversation" do
    other = create(:conversation)
    get "/api/v1/accounts/#{account.id}/crm/conversations/#{other.display_id + 1000}", headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end
end
