# Custom (MyDesk): phase 2 of docs/reports/CRM_REPORTS_PLAN.md. An employee never reaches a colleague's deal, by any
# screen, report, direct link, export or live update; only the manager reassigns deals and exports.
require 'rails_helper'

RSpec.describe 'Sales CRM visibility', type: :request do # -- request spec across controllers
  let(:account) { create(:account) }
  let(:period) { { from: Date.current.beginning_of_month.iso8601, to: Date.current.iso8601 } }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/crm" }
  let(:pipeline) { SalesCrm::Pipelines::EnsureDefault.call(account) }
  let(:contact) { create(:contact, account: account) }
  let(:mine) { deal_for(agent, title: 'صفقتي') }
  let(:theirs) { deal_for(colleague, title: 'صفقة الزميل', amount: '90000') }

  # A fresh token per request: the integration session would otherwise carry the previous request into this hash
  def auth = agent.create_new_auth_token

  def deal_for(user, attrs = {})
    SalesCrm::Deals::Create.new(account: account, user: user)
                           .perform({ title: 'باقة', amount: '50000', close_date: Date.current + 30, pipeline_id: pipeline.id,
                                      contact_id: contact.id, assignee_id: user.id }.merge(attrs))
  end

  def won!(deal)
    SalesCrm::Deals::Move.new(account: account, user: deal.assignee).perform(deal, stage_id: pipeline.won_stage.id)
  end

  before do
    account.enable_features!('sales_crm')
    mine
    theirs
  end

  it 'keeps the colleague deal off the board, the table, the forecast and the contact panel' do
    get "#{base}/deals", params: { pipeline_id: pipeline.id }, headers: auth, as: :json
    expect(response.parsed_body['deals'].pluck('id')).to eq([mine.id])
    get "#{base}/deals", params: { pipeline_id: pipeline.id, view: 'table', assignee_id: colleague.id }, headers: auth, as: :json
    expect(response.parsed_body['deals'].pluck('id')).to eq([])
    get "#{base}/deals/forecast", params: { pipeline_id: pipeline.id }, headers: auth, as: :json
    expect(response.parsed_body['open_total_cents']).to eq(5_000_000)
    get "#{base}/contacts/#{contact.id}/summary", headers: auth, as: :json
    expect(response.parsed_body['deals'].pluck('id')).to eq([mine.id])
  end

  it 'answers 404 to every direct link and action on the colleague deal' do
    requests = [
      [:get, "deals/#{theirs.id}"], [:patch, "deals/#{theirs.id}", { deal: { title: 'x' } }],
      [:patch, "deals/#{theirs.id}/move", { stage_id: pipeline.won_stage.id }], [:post, "deals/#{theirs.id}/reopen"],
      [:delete, "deals/#{theirs.id}"], [:get, "deals/#{theirs.id}/notes"], [:post, "deals/#{theirs.id}/notes", { content: 'x' }],
      [:get, "deals/#{theirs.id}/activities"]
    ]
    requests.each do |verb, path, body|
      public_send(verb, "#{base}/#{path}", params: body || {}, headers: auth, as: :json)
      expect(response).to have_http_status(:not_found), "#{verb} #{path} gave #{response.status}"
    end
    expect(theirs.reload.title).to eq('صفقة الزميل')
  end

  it 'keeps the colleague deal tasks out of every task tab, and refuses a task on it' do
    create(:crm_task, account: account, deal: theirs, assignee: colleague, creator: colleague, title: 'مهمة الزميل', due_at: 1.hour.ago)
    own = create(:crm_task, account: account, deal: mine, assignee: agent, creator: agent, due_at: 1.hour.ago)
    %w[mine today overdue upcoming done all].each do |scope|
      get "#{base}/tasks", params: { scope: scope }, headers: auth, as: :json
      expect(response.parsed_body['tasks'].pluck('title')).not_to include('مهمة الزميل')
    end
    get "#{base}/tasks", params: { deal_id: theirs.id }, headers: auth, as: :json
    expect(response.parsed_body['tasks']).to be_empty
    get "#{base}/tasks", params: { scope: 'overdue' }, headers: auth, as: :json
    expect(response.parsed_body['tasks'].pluck('id')).to eq([own.id])
    post "#{base}/tasks", params: { task: { title: 'x', deal_id: theirs.id } }, headers: auth, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'gives the employee only their own numbers in every report, whatever assignee they ask for' do
    won!(mine)
    won!(theirs)
    get "#{base}/reports/summary", params: period.merge(assignee_id: colleague.id), headers: auth, as: :json
    expect(response.parsed_body['current']).to include('won_count' => 1, 'won_total_cents' => 5_000_000)
    get "#{base}/reports/agents", params: period, headers: auth, as: :json
    expect(response.parsed_body.pluck('user_id')).to eq([agent.id])
    get "#{base}/reports/timeline", params: period, headers: auth, as: :json
    expect(response.parsed_body.sum { |b| b['won'] }).to eq(1)
    get "#{base}/reports/funnel", params: period.merge(pipeline_id: pipeline.id), headers: auth, as: :json
    expect(response.parsed_body.first['reached_count']).to eq(1)
  end

  it 'lets only the manager export' do
    get "#{base}/reports/export", params: period, headers: auth
    expect(response).to have_http_status(:unauthorized)
    get "#{base}/reports/export", params: period, headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('صفقة الزميل')
  end

  it 'lets only the manager hand a deal to someone else' do
    patch "#{base}/deals/#{mine.id}", params: { deal: { assignee_id: colleague.id } }, headers: auth, as: :json
    expect(response).to have_http_status(:unauthorized)
    post "#{base}/deals", params: { deal: { title: 'x', amount: '10', close_date: Date.current + 5, assignee_id: colleague.id } },
                          headers: auth, as: :json
    expect(response).to have_http_status(:unauthorized)
    post "#{base}/deals", params: { deal: { title: 'لي', amount: '10', close_date: Date.current + 5, pipeline_id: pipeline.id } }, headers: auth,
                          as: :json
    expect(response.parsed_body).to include('assignee' => include('id' => agent.id))
    patch "#{base}/deals/#{mine.id}", params: { deal: { assignee_id: colleague.id } }, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(mine.reload.assignee_id).to eq(colleague.id)
  end

  it 'sends live updates of a deal only to the managers and its owner' do
    expect do
      SalesCrm::Deals::Update.new(account: account, user: colleague).perform(theirs, title: 'جديد')
    end.to have_enqueued_job(ActionCableBroadcastJob).with(
      contain_exactly(admin.pubsub_token, colleague.pubsub_token), 'crm.deal_updated', anything
    )
  end
end
