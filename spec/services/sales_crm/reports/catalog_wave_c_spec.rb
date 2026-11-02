# Custom (MyDesk): phase 4 wave ج of docs/reports/CRM_REPORTS_PLAN.md, reports 9, 11, 13, 17 and 18, which read the
# activity log. A handful of deals and logged moves per report, the expected numbers worked out by hand in the
# comments. "Today" is 20 October 2026, 10:00 in Riyadh.
require 'rails_helper'

RSpec.describe SalesCrm::Reports::Catalog do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:riyadh) { ActiveSupport::TimeZone['Asia/Riyadh'] }

  around { |example| travel_to(ActiveSupport::TimeZone['Asia/Riyadh'].local(2026, 10, 20, 10, 0)) { example.run } }

  def stage(probability) = pipeline.stages.find { |s| s.open? && s.probability == probability }
  def day(month, date) = riyadh.local(2026, month, date)

  def deal(attrs = {})
    create(:crm_deal, { account: account, pipeline: pipeline, stage: stage(10), assignee: agent, close_date: Date.new(2026, 11, 30) }
      .merge(attrs))
  end

  def logged(target, kind, at, data = {})
    account.crm_activities.create!(deal: target, kind: kind, data: data, created_at: at)
    target
  end

  def run(key, user, **filters) = SalesCrm::Reports::Catalog.fetch(key).new(account: account, user: user, **filters).perform

  def drill(key, user, cell, **filters)
    SalesCrm::Reports::Catalog.fetch(key).new(account: account, user: user, cell: cell, **filters).drill
  end

  describe SalesCrm::Reports::Conversion do
    before do
      lead = stage(10)
      qualified = stage(25)
      proposal = stage(50)
      first = deal(stage: proposal, created_at: day(10, 2))
      logged(first, 'created', day(10, 2), stage_id: lead.id)
      logged(first, 'stage_changed', day(10, 3), from_stage_id: lead.id, to_stage_id: qualified.id)
      logged(first, 'stage_changed', day(10, 4), from_stage_id: qualified.id, to_stage_id: proposal.id)
      second = deal(stage: qualified, created_at: day(10, 2), assignee: colleague)
      logged(second, 'created', day(10, 2), stage_id: lead.id)
      logged(second, 'stage_changed', day(10, 5), from_stage_id: lead.id, to_stage_id: qualified.id)
      logged(deal(created_at: day(10, 3)), 'created', day(10, 3), stage_id: lead.id)
      won = deal(stage: pipeline.won_stage, status: :won, won_at: day(10, 9), created_at: day(10, 6))
      logged(won, 'created', day(10, 6), stage_id: lead.id)
      logged(won, 'stage_changed', day(10, 9), from_stage_id: lead.id, to_stage_id: pipeline.won_stage.id) # skipped the rest
      logged(deal(created_at: day(9, 20)), 'created', day(9, 20), stage_id: lead.id) # created before the period
    end

    it 'counts the deals reaching each stage and the share going on, and finds the leak' do
      result = run('conversion', admin)
      # lead 4 → qualified 3 (75.0%) → proposal 2 (66.7%) → negotiation 1 (50.0%) → won 1 (100.0%)
      expect(result[:rows].map { |r| [r[:count], r[:rate]] }).to eq([[4, nil], [3, 75.0], [2, 66.7], [1, 50.0], [1, 100.0]])
      expect(result[:leak_stage_id]).to eq(stage(75).id)
      expect(drill('conversion', admin, { stage_id: stage(50).id })[:total_count]).to eq(2)
    end

    it 'puts each employee rates beside the team' do
      theirs = run('conversion', admin)[:assignees].find { |r| r[:assignee_id] == colleague.id }
      expect(theirs[:stages].second).to include(count: 1, rate: 100.0, team_rate: 75.0)
      expect(run('conversion', agent)[:rows].first[:count]).to eq(3)
    end
  end

  describe SalesCrm::Reports::Cycle do
    before do
      lead = stage(10)
      qualified = stage(25)
      proposal = stage(50)
      logged_deal = deal(stage: proposal, created_at: day(10, 1))
      logged(logged_deal, 'created', day(10, 1), stage_id: lead.id)
      logged(logged_deal, 'stage_changed', day(10, 5), from_stage_id: lead.id, to_stage_id: qualified.id)
      logged(logged_deal, 'stage_changed', day(10, 15), from_stage_id: qualified.id, to_stage_id: proposal.id) # still there
      # created before the log: its first stay, in lead, is taken from its creation date
      older = deal(stage: pipeline.won_stage, status: :won, won_at: day(10, 13), created_at: day(9, 25), assignee: colleague)
      logged(older, 'stage_changed', day(10, 3), from_stage_id: lead.id, to_stage_id: qualified.id)
      logged(older, 'stage_changed', day(10, 13), from_stage_id: qualified.id, to_stage_id: pipeline.won_stage.id)
    end

    it 'averages the days of the stays that ended in the period, stage by stage' do
      result = run('cycle', admin)
      # lead: 4 days and 8 days → 6.0; qualified: 10 and 10 → 10.0; proposal: still there
      expect(result[:stages].first(3).map { |s| [s[:count], s[:average_days]] }).to eq([[2, 6.0], [2, 10.0], [0, nil]])
      expect(result).to include(cycle_days: 18.0, approximate_count: 1) # won 13 Oct, created 25 Sep
      expect(drill('cycle', admin, { stage_id: stage(10).id })[:total_count]).to eq(2)
    end

    it 'splits the days by employee' do
      theirs = run('cycle', admin)[:assignees].find { |r| r[:assignee_id] == colleague.id }
      expect(theirs[:stages].first(2).pluck(:average_days)).to eq([8.0, 10.0])
      expect(theirs[:cycle_days]).to eq(18.0)
    end
  end

  describe SalesCrm::Reports::Changes do
    before do
      lead = stage(10)
      qualified = stage(25)
      proposal = stage(50)
      moved = deal(stage: qualified, amount_cents: 100_000, created_at: day(10, 1))
      logged(moved, 'created', day(10, 1), stage_id: lead.id)
      logged(moved, 'stage_changed', day(10, 16), from_stage_id: lead.id, to_stage_id: qualified.id) # advanced
      logged(moved, 'amount_changed', day(10, 17), from: 80_000, to: 100_000) # +20,000
      back = deal(stage: qualified, amount_cents: 200_000, created_at: day(10, 1), close_date: Date.new(2026, 11, 10))
      logged(back, 'created', day(10, 1), stage_id: proposal.id)
      logged(back, 'stage_changed', day(10, 15), from_stage_id: proposal.id, to_stage_id: qualified.id) # moved back
      logged(back, 'close_date_changed', day(10, 16), from: '2026-10-25', to: '2026-11-10') # slipped
      logged(deal(amount_cents: 50_000, created_at: day(10, 16)), 'created', day(10, 16), stage_id: lead.id) # new
      deal(amount_cents: 300_000, created_at: day(10, 1), status: :won, stage: pipeline.won_stage, won_at: day(10, 18))
      deal(amount_cents: 40_000, created_at: day(10, 1), status: :lost, stage: pipeline.lost_stage, lost_at: day(10, 2), lost_reason: 'x')
      deal(amount_cents: 60_000, created_at: day(10, 1)) # unchanged
    end

    it 'counts what moved in the last 7 days' do
      result = run('changes', admin)
      expect(result[:period]).to eq(from: '2026-10-14', to: '2026-10-20')
      expect(result[:totals][:counts]).to eq('new' => 1, 'advanced' => 1, 'moved_back' => 1, 'slipped' => 1, 'won' => 1, 'lost' => 0,
                                             'increased' => 1, 'decreased' => 0)
      expect(drill('changes', admin, { move: 'slipped' })[:total_count]).to eq(1)
    end

    it 'runs the waterfall from the open value at the start to the open value at the end' do
      # start: 80,000 + 200,000 + 300,000 + 60,000; end: 100,000 + 200,000 + 50,000 + 60,000
      expect(run('changes', admin)[:totals][:waterfall]).to eq(start: 640_000, new: 50_000, increased: 20_000, decreased: 0,
                                                               won: 300_000, lost: 0, end: 410_000)
    end
  end

  describe SalesCrm::Reports::Revenue do
    let(:product_a) { account.crm_list_items.create!(list: 'product', name: 'أ') }
    let(:product_b) { account.crm_list_items.create!(list: 'product', name: 'ب') }
    let(:retail) { account.crm_list_items.create!(list: 'industry', name: 'تجزئة') }

    def won(cents, at, **attrs) = deal(amount_cents: cents, status: :won, stage: pipeline.won_stage, won_at: at, **attrs)

    before do
      won(300_000, day(10, 3), product_id: product_a.id, industry_id: retail.id)
      won(100_000, day(10, 4), product_id: product_a.id)
      won(100_000, day(10, 5), product_id: product_b.id, assignee: colleague)
      won(200_000, day(9, 20), product_id: product_a.id) # the period before: 11–30 September
    end

    it 'gives each product its revenue, share and growth' do
      rows = run('revenue', admin)[:rows]
      # A: 400,000 of 500,000 = 80.0%, up from 200,000 = +100.0%; B: new
      expect(rows.map { |r| [r[:name], r[:total_cents], r[:share], r[:growth]] }).to eq([['أ', 400_000, 80.0, 100.0],
                                                                                         ['ب', 100_000, 20.0, nil]])
      expect(drill('revenue', admin, rows.first[:cell])).to include(total_count: 2, total_cents: 400_000)
    end

    it 'groups by industry too, those without one as not set' do
      rows = run('revenue', admin, group_by: 'industry')[:rows]
      expect(rows.map { |r| [r[:id], r[:share]] }).to eq([[retail.id, 60.0], [nil, 40.0]])
    end
  end

  describe SalesCrm::Reports::DealSize do
    def won(cents, at, **attrs) = deal(amount_cents: cents, status: :won, stage: pipeline.won_stage, won_at: at, **attrs)

    before do
      won(100_000, day(1, 10))
      won(300_000, day(1, 20))
      won(500_000, day(3, 5), assignee: colleague)
      won(0, day(10, 1)) # no amount: left out
    end

    it 'averages the won deals month by month over this year' do
      result = run('deal_size', admin)
      expect(result[:period]).to eq(from: '2026-01-01', to: '2026-10-20')
      expect(result[:totals]).to eq(average_cents: 300_000, won_count: 3)
      expect(result[:buckets].size).to eq(10)
      expect(result[:buckets].first(3).map { |b| [b[:count], b[:average_cents]] }).to eq([[2, 200_000], [0, nil], [1, 500_000]])
      expect(drill('deal_size', admin, result[:buckets].first[:cell])).to include(total_count: 2, total_cents: 400_000)
    end

    it 'gives each employee their own line' do
      theirs = run('deal_size', admin)[:assignees].find { |r| r[:assignee_id] == colleague.id }
      expect(theirs).to include(average_cents: 500_000, count: 1)
    end
  end
end
