# Custom (MyDesk): a deal's follow-up, won and lost suggestions in the conversation panel (CONVERSATION_SALES_PLAN.md, ج2)
require 'rails_helper'

RSpec.describe 'Sales CRM suggestions API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:handler) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: handler) }
  let(:deal) { create(:crm_deal, account: account, assignee: owner, conversation: conversation) }
  let!(:suggestion) { SalesCrm::Suggestion.create!(account: account, conversation: conversation, deal: deal, kind: :follow_up) }
  let(:base) { "/api/v1/accounts/#{account.id}/crm/suggestions/#{suggestion.id}" }

  before { account.enable_features!('sales_crm') }

  it "writes the draft for the deal's owner, and says whether the conversation still takes a free text" do
    allow(SalesCrm::MessageDraft).to receive(:new).and_return(instance_double(SalesCrm::MessageDraft, perform: 'هلا'))

    post "#{base}/draft", headers: owner.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('draft' => 'هلا', 'can_reply' => true)
  end

  it "keeps a colleague's deal suggestion away from the employee handling the conversation" do
    post "#{base}/draft", headers: handler.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'marks the suggestion used once the employee takes the draft' do
    post "#{base}/accept", headers: owner.create_new_auth_token, as: :json
    expect(suggestion.reload).to have_attributes(status: 'accepted', decided_by_id: owner.id)
  end

  it 'lists the deal suggestions in the conversation for their owner' do
    get "/api/v1/accounts/#{account.id}/crm/conversations/#{conversation.display_id}", headers: owner.create_new_auth_token, as: :json
    expect(response.parsed_body['suggestions']).to contain_exactly(include('id' => suggestion.id, 'kind' => 'follow_up',
                                                                           'deal_title' => deal.title))
  end
end
