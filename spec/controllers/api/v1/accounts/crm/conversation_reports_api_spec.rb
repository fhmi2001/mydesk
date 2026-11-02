# Custom (MyDesk): who may open the conversation and sales reports (CONVERSATION_SALES_PLAN.md, phase 4): report 21 is
# the manager's alone, refused by the server for its page, its deals and its file; 20 and 22 give an employee their own.
require 'rails_helper'

RSpec.describe 'Sales CRM conversation reports API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/crm/reports" }

  before { account.enable_features!('sales_crm') }

  it 'refuses the campaign return to an employee: the report, its deals and its file' do
    ["#{base}/campaigns", "#{base}/campaigns/deals", "#{base}/campaigns/download"].each do |path|
      get path, params: { cell: { campaign_id: 1 } }, headers: agent.create_new_auth_token
      expect(response).to have_http_status(:unauthorized), path
    end
    get "#{base}/campaigns", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
  end

  it 'opens response speed and conversation to deal for an employee, and their file for the manager only' do
    %w[response_speed conversation_deals].each do |key|
      get "#{base}/#{key}", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok), key
      get "#{base}/#{key}/download", headers: agent.create_new_auth_token
      expect(response).to have_http_status(:unauthorized), key
    end
  end

  it 'exports each new report for the manager' do
    %w[response_speed campaigns conversation_deals].each do |key|
      get "#{base}/#{key}/download", headers: admin.create_new_auth_token
      expect(response).to have_http_status(:ok), key
    end
  end
end
