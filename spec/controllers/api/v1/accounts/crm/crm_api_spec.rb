# Custom (MyDesk): Sales CRM API
require 'rails_helper'

RSpec.describe 'Sales CRM API', type: :request do # -- request spec across controllers
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_account) { create(:account) }
  let(:outsider) { create(:user, account: other_account, role: :administrator) }
  let(:base) { "/api/v1/accounts/#{account.id}/crm" }
  let(:pipeline) { SalesCrm::Pipelines::EnsureDefault.call(account) }
  let(:lost) { pipeline.lost_stage }

  def deal_for(user, attrs = {})
    SalesCrm::Deals::Create.new(account: account, user: user)
                           .perform({ title: 'باقة', amount: '50000', pipeline_id: pipeline.id, assignee_id: user.id }.merge(attrs))
  end

  context 'when the feature is off' do
    it 'status says disabled and the rest is 403' do
      get "#{base}/status", headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body).to eq('enabled' => false)
      get "#{base}/deals", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']).to eq('crm_disabled')
    end
  end

  context 'when the feature is on' do
    before { account.enable_features!('sales_crm') }

    it 'status returns the admin flag, overdue count and settings' do
      create(:crm_task, account: account, assignee: agent, due_at: 1.hour.ago)
      get "#{base}/status", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body).to include('enabled' => true, 'is_admin' => false, 'overdue_count' => 1)
      expect(response.parsed_body['settings']).to include('default_currency' => 'SAR', 'timezone' => 'Asia/Riyadh')
    end

    it 'board index returns deals, per-stage counts and the forecast' do
      deal_for(agent)
      get "#{base}/deals", params: { pipeline_id: pipeline.id }, headers: agent.create_new_auth_token, as: :json
      body = response.parsed_body
      expect(body['deals'].size).to eq(1)
      expect(body['deals'].first).to include('title' => 'باقة', 'amount' => '50000.00', 'currency' => 'SAR')
      expect(body['counts'][pipeline.first_open_stage.id.to_s]).to eq('count' => 1, 'total_cents' => 5_000_000)
      get "#{base}/deals/forecast", params: { pipeline_id: pipeline.id }, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body).to include('open_count' => 1, 'expected_cents' => 500_000)
    end

    it 'cannot read another account deal: 404 from scoping, and outsiders get 401' do
      deal = deal_for(admin)
      get "#{base}/deals/#{deal.id}", headers: outsider.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
      foreign = create(:crm_deal, account: other_account)
      get "#{base}/deals/#{foreign.id}", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it 'agent with own-deals-only cannot see or move others deals' do
      account.update!(crm_agents_see_own_deals_only: true)
      theirs = deal_for(admin)
      get "#{base}/deals/#{theirs.id}", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
      patch "#{base}/deals/#{theirs.id}/move", params: { stage_id: lost.id, lost_reason: 'x' }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
      get "#{base}/deals", params: { pipeline_id: pipeline.id }, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['deals']).to be_empty
    end

    it 'agent cannot write pipelines or settings' do
      patch "#{base}/pipelines/#{pipeline.id}", params: { name: 'x' }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
      patch "#{base}/settings", params: { settings: { agents_see_own_deals_only: true } }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'move to lost without a reason is 422 with a translated message' do
      deal = deal_for(agent)
      patch "#{base}/deals/#{deal.id}/move", params: { stage_id: lost.id }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['message']).to be_present
    end

    it 'stale update is 409' do
      deal = deal_for(agent)
      patch "#{base}/deals/#{deal.id}", params: { deal: { title: 'a', lock_version: 0 } }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:success)
      patch "#{base}/deals/#{deal.id}", params: { deal: { title: 'b', lock_version: 0 } }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body['error']).to eq('stale')
    end

    it 'deleting a stage with deals and no target is 422; with a target it moves them' do
      deal = deal_for(agent, stage_id: pipeline.stages[1].id)
      kept = pipeline.stages.reject { |s| s.id == pipeline.stages[1].id }
      rows = kept.map { |s| { id: s.id, name: s.name, probability: s.probability, kind: s.kind } }
      patch "#{base}/pipelines/#{pipeline.id}", params: { stages: rows }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      patch "#{base}/pipelines/#{pipeline.id}", params: { stages: rows, stage_moves: { pipeline.stages[1].id => pipeline.stages[0].id } },
                                                headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:success)
      expect(deal.reload.stage).to eq(pipeline.stages.reload[0])
    end

    it 'creates a deal from a conversation, lists notes and activities' do
      contact = create(:contact, account: account)
      conversation = create(:conversation, account: account, contact: contact)
      post "#{base}/deals", params: { deal: { title: 'من المحادثة', amount: '١٢٣٤', pipeline_id: pipeline.id, contact_id: contact.id,
                                              conversation_id: conversation.display_id } }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:success)
      id = response.parsed_body['id']
      expect(response.parsed_body).to include('amount' => '1234.00', 'source' => 'conversation_source', 'conversation_id' => conversation.id)
      post "#{base}/deals/#{id}/notes", params: { content: 'ملاحظة' }, headers: agent.create_new_auth_token, as: :json
      get "#{base}/deals/#{id}/activities", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body.map { |a| a['kind'] }).to eq(%w[note_added created])
      get "#{base}/contacts/#{contact.id}/summary", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['deals'].size).to eq(1)
    end

    it 'tasks: create, scopes, complete, overdue count' do
      post "#{base}/tasks", params: { task: { title: 'اتصل', due_at: 1.hour.ago.iso8601 } }, headers: agent.create_new_auth_token, as: :json
      id = response.parsed_body['id']
      get "#{base}/tasks", params: { scope: 'overdue' }, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['tasks'].map { |t| t['id'] }).to eq([id])
      expect(response.parsed_body['overdue_count']).to eq(1)
      post "#{base}/tasks/#{id}/complete", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['status']).to eq('done')
      get "#{base}/tasks", params: { scope: 'done' }, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['tasks'].size).to eq(1)
    end

    it 'tasks: one task by id for its direct link, never another account\'s' do
      post "#{base}/tasks", params: { task: { title: 'تابع العرض' } }, headers: agent.create_new_auth_token, as: :json
      id = response.parsed_body['id']
      get "#{base}/tasks/#{id}", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('id' => id, 'title' => 'تابع العرض')
      other_account.enable_features!('sales_crm')
      get "/api/v1/accounts/#{other_account.id}/crm/tasks/#{id}", headers: outsider.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it 'discard, discarded list and restore (admin)' do
      deal = deal_for(agent)
      delete "#{base}/deals/#{deal.id}", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
      get "#{base}/deals/discarded", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
      get "#{base}/deals/discarded", headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['deals'].map { |d| d['id'] }).to eq([deal.id])
      post "#{base}/deals/#{deal.id}/restore", headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:success)
      expect(deal.reload).not_to be_discarded
    end

    it 'reports: summary for admin, export as csv' do
      deal_for(agent)
      get "#{base}/reports/summary", params: { from: Date.current.beginning_of_month, to: Date.current }, headers: admin.create_new_auth_token,
                                     as: :json
      expect(response.parsed_body['current']).to include('open_count' => 1)
      get "#{base}/reports/export", params: { from: Date.current.beginning_of_month, to: Date.current }, headers: admin.create_new_auth_token
      expect(response.content_type).to include('text/csv')
      expect(response.body).to include('باقة')
    end

    it 'settings update by admin' do
      patch "#{base}/settings", params: { settings: { agents_see_own_deals_only: true, default_currency: 'aed' } },
                                headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body).to include('agents_see_own_deals_only' => true, 'default_currency' => 'AED')
      patch "#{base}/settings", params: { settings: { default_currency: 'XXX' } }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
