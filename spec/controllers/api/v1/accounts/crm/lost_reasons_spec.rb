# Custom (MyDesk): lost reasons list and notes on a lost deal
require 'rails_helper'

RSpec.describe 'Sales CRM lost reasons', type: :request do # -- request spec
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/crm" }
  let(:pipeline) { SalesCrm::Pipelines::EnsureDefault.call(account) }

  before { account.enable_features!('sales_crm') }

  it 'seeds the five default reasons once and lets every agent read them' do
    get "#{base}/lost_reasons", headers: agent.create_new_auth_token, as: :json
    get "#{base}/lost_reasons", headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.map { |r| r['name'] }).to eq(SalesCrm::LostReason::DEFAULTS)
  end

  it 'lets administrators add, rename, reorder and delete; agents get 401' do
    post "#{base}/lost_reasons", params: { name: 'جديد' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)

    post "#{base}/lost_reasons", params: { name: '  تأخر التوصيل ' }, headers: admin.create_new_auth_token, as: :json
    names = response.parsed_body.map { |r| r['name'] }
    expect(names.last).to eq('تأخر التوصيل')

    ids = response.parsed_body.map { |r| r['id'] }
    patch "#{base}/lost_reasons/reorder", params: { ids: ids.reverse }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body.first['name']).to eq('تأخر التوصيل')

    patch "#{base}/lost_reasons/#{ids.first}", params: { name: 'السعر أعلى من المنافس' }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body.map { |r| r['name'] }).to include('السعر أعلى من المنافس')

    delete "#{base}/lost_reasons/#{ids.first}", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body.size).to eq(5)
  end

  it 'refuses a duplicate name (case-insensitive) with 422' do
    get "#{base}/lost_reasons", headers: admin.create_new_auth_token, as: :json
    post "#{base}/lost_reasons", params: { name: 'أخرى' }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'cannot touch another account reason' do
    other = create(:account)
    foreign = other.crm_lost_reasons.create!(name: 'x')
    delete "#{base}/lost_reasons/#{foreign.id}", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'keeps the note with a lost deal, shows it, and clears both on reopen' do
    deal = SalesCrm::Deals::Create.new(account: account, user: agent).perform(title: 'd', amount: '10', close_date: Date.current + 30,
                                                                              pipeline_id: pipeline.id)
    patch "#{base}/deals/#{deal.id}/move",
          params: { stage_id: pipeline.lost_stage.id, lost_reason: 'السعر مرتفع', lost_note: '  طلب خصم 30%  ' },
          headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('lost_reason' => 'السعر مرتفع', 'lost_note' => 'طلب خصم 30%')
    expect(deal.reload.activities.find_by(kind: 'lost').data).to include('note' => 'طلب خصم 30%')

    post "#{base}/deals/#{deal.id}/reopen", headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('lost_reason' => nil, 'lost_note' => nil)
  end
end
