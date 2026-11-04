# Custom (MyDesk): the deal badges on the conversation list (CONVERSATION_SALES_PLAN.md)
require 'rails_helper'

RSpec.describe 'Sales CRM contact badges API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:offer) { pipeline.stages.find { |stage| stage.name == 'تم إرسال العرض' } }
  let(:lead) { pipeline.stages.find { |stage| stage.name == 'عميل محتمل' } }
  let(:sara) { create(:contact, account: account) }
  let(:omar) { create(:contact, account: account) }
  let(:path) { "/api/v1/accounts/#{account.id}/crm/contact_badges" }

  before do
    account.enable_features!('sales_crm')
    create(:crm_deal, account: account, pipeline: pipeline, stage: lead, contact: sara, assignee: agent, amount_cents: 1_000)
    create(:crm_deal, account: account, pipeline: pipeline, stage: offer, contact: sara, assignee: agent, amount_cents: 5_000)
    create(:crm_deal, account: account, pipeline: pipeline, stage: pipeline.won_stage, status: :won, contact: sara, assignee: agent)
    create(:crm_deal, account: account, pipeline: pipeline, stage: lead, contact: omar, assignee: admin, amount_cents: 7_000)
  end

  def badges_for(user, ids)
    get path, params: { contact_ids: ids }, headers: user.create_new_auth_token
    response.parsed_body['badges']
  end

  it "counts each contact's open deals and names the stage of the biggest" do
    expect(badges_for(admin, [sara.id, omar.id])[sara.id.to_s]).to include(
      'count' => 2, 'total_cents' => 6_000, 'stage' => include('name' => 'تم إرسال العرض', 'color' => offer.color)
    )
  end

  it "shows an employee only their own deals, so a colleague's contact gets no badge" do
    badges = badges_for(agent, [sara.id, omar.id])
    expect(badges.keys).to eq([sara.id.to_s])
  end

  it 'takes at most 100 contacts' do
    get path, params: { contact_ids: (1..101).to_a }, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
