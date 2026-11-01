# Custom (MyDesk): the API of phase 4 wave أ (docs/reports/CRM_REPORTS_PLAN.md): GET crm/reports/:key gives one
# report's numbers to both roles, GET crm/reports/:key/deals the deals behind one of them. The numbers themselves are
# in spec/services/sales_crm/reports_wave_a_spec.rb.
require 'rails_helper'

RSpec.describe 'Sales CRM reports, wave أ', type: :request do # -- request spec across one controller's actions
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/crm/reports" }
  let(:pipeline) { create(:crm_pipeline, account: account) }

  before do
    account.enable_features!('sales_crm')
    create(:crm_deal, account: account, pipeline: pipeline, assignee: agent, amount_cents: 100_000)
    create(:crm_deal, account: account, pipeline: pipeline, assignee: colleague, amount_cents: 400_000)
  end

  it 'serves every report of the wave' do
    SalesCrm::Reports::Catalog::REPORTS.each_key do |key|
      get "#{base}/#{key}", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok), key
      expect(response.parsed_body).to include('key' => key, 'currency' => 'SAR', 'team' => key != 'my_tasks')
    end
  end

  it 'gives the manager the team and the deals behind a number' do
    get "#{base}/pipeline_by_stage", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['totals']).to include('count' => 2, 'total_cents' => 500_000)

    get "#{base}/pipeline_by_stage/deals", params: { cell: { assignee_id: colleague.id } }, headers: admin.create_new_auth_token
    expect(response.parsed_body).to include('total_count' => 1, 'total_cents' => 400_000)
    expect(response.parsed_body['items'].sole['assignee']['id']).to eq(colleague.id)
  end

  it 'gives an employee their own numbers, whatever employee or cell they ask for' do
    get "#{base}/pipeline_by_stage", params: { assignee_id: colleague.id }, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('team' => false)
    expect(response.parsed_body['totals']).to include('count' => 1, 'total_cents' => 100_000)

    get "#{base}/pipeline_by_stage/deals", params: { cell: { assignee_id: colleague.id } }, headers: agent.create_new_auth_token
    expect(response.parsed_body['items'].pluck('amount_cents')).to eq([100_000])
  end

  it 'keeps the team reports for the manager' do
    %w[activity cycle changes revenue deal_size].each do |key|
      get "#{base}/#{key}", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized), key
    end
    get "#{base}/activity/deals", params: { cell: { kind: 'call' } }, headers: agent.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
  end

  it 'knows no other report' do
    get "#{base}/nonsense", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end
end
