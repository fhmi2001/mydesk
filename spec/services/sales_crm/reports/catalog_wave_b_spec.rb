# Custom (MyDesk): phase 4 wave ب of docs/reports/CRM_REPORTS_PLAN.md, reports 8, 10, 12, 14, 15, 16 and 19. A handful
# of deals per report, the expected numbers worked out by hand in the comments; the deals behind a number add up to
# it; an employee only ever gets their own. "Today" is 20 October 2026, 10:00 in Riyadh.
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

  def deal(attrs = {})
    create(:crm_deal, { account: account, pipeline: pipeline, stage: stage(10), assignee: agent, close_date: Date.new(2026, 11, 30) }
      .merge(attrs))
  end

  def won(cents, at, **attrs)
    deal(amount_cents: cents, status: :won, stage: pipeline.won_stage, won_at: at, created_at: at - 10.days, **attrs)
  end

  def lost(cents, at, reason = 'x', **attrs)
    deal(amount_cents: cents, status: :lost, stage: pipeline.lost_stage, lost_at: at, lost_reason: reason, created_at: at - 10.days,
         **attrs)
  end

  def item(list, name) = account.crm_list_items.create!(list: list, name: name)
  def target(user, cents) = create(:crm_target, account: account, user: user, period_start: Date.new(2026, 10, 1), amount_cents: cents)

  def run(key, user, **filters) = SalesCrm::Reports::Catalog.fetch(key).new(account: account, user: user, **filters).perform

  def drill(key, user, cell, **filters)
    SalesCrm::Reports::Catalog.fetch(key).new(account: account, user: user, cell: cell, **filters).drill
  end

  describe SalesCrm::Reports::Coverage do
    before do
      target(agent, 3_000_000)
      target(colleague, 1_000_000)
      won(1_000_000, riyadh.local(2026, 10, 5))
      deal(amount_cents: 3_000_000, close_date: Date.new(2026, 10, 28))
      deal(amount_cents: 9_000_000, close_date: Date.new(2026, 11, 5)) # next month
      deal(amount_cents: 500_000, close_date: Date.new(2026, 10, 30), assignee: colleague)
    end

    it 'divides the open value closing this month by what is left of the target, and rates it' do
      result = run('coverage', admin)
      # 3,500,000 open ÷ (4,000,000 − 1,000,000) = 1.17 → 1.2: under 3 times, but above once
      expect(result[:totals]).to include(open_cents: 3_500_000, won_cents: 1_000_000, target_cents: 4_000_000,
                                         remaining_cents: 3_000_000, coverage: 1.2, rating: 'warn')
      # agent 3,000,000 ÷ 2,000,000 = 1.5; colleague 500,000 ÷ 1,000,000 = 0.5, listed first
      expect(result[:assignees].map { |r| [r[:assignee_id], r[:coverage], r[:rating]] }).to eq([[colleague.id, 0.5, 'bad'],
                                                                                                [agent.id, 1.5, 'warn']])
      expect(drill('coverage', admin, { status: 'open' })).to include(total_count: 2, total_cents: 3_500_000)
    end

    it 'gives an employee their own coverage, and nothing to cover once the target is met' do
      expect(run('coverage', agent)).to include(assignees: nil, totals: include(coverage: 1.5))
      won(2_000_000, riyadh.local(2026, 10, 6))
      expect(run('coverage', agent)[:totals]).to include(remaining_cents: 0, coverage: nil, rating: nil)
    end
  end

  describe SalesCrm::Reports::WinRates do
    let(:product_a) { item('product', 'أ') }
    let(:product_b) { item('product', 'ب') }

    before do
      won(100_000, riyadh.local(2026, 10, 3), product_id: product_a.id)
      lost(100_000, riyadh.local(2026, 10, 4), product_id: product_a.id)
      won(300_000, riyadh.local(2026, 10, 5), product_id: product_b.id)
      lost(200_000, riyadh.local(2026, 10, 6), assignee: colleague, product_id: product_b.id)
      lost(50_000, riyadh.local(2026, 10, 7), assignee: colleague)
    end

    it 'compares employees by count and by value' do
      rows = run('win_rate', admin)[:rows]
      # agent: 2 of 3 = 66.7%, 400,000 of 500,000 = 80.0%; colleague: 0 of 2
      expect(rows.find { |r| r[:id] == agent.id }).to include(by_count: 66.7, by_value: 80.0)
      expect(rows.find { |r| r[:id] == colleague.id }).to include(by_count: 0.0, by_value: 0.0)
    end

    it 'compares products, those without one too, and opens the deals of a group' do
      rows = run('win_rate', admin, group_by: 'product')[:rows]
      # A: 1 of 2, 100,000 of 200,000; B: 1 of 2, 300,000 of 500,000 = 60.0%
      expect(rows.find { |r| r[:id] == product_a.id }).to include(name: 'أ', by_count: 50.0, by_value: 50.0)
      expect(rows.find { |r| r[:id] == product_b.id }).to include(by_count: 50.0, by_value: 60.0)
      expect(drill('win_rate', admin, { product_id: product_b.id, status: 'lost' })).to include(total_count: 1, total_cents: 200_000)
      expect(drill('win_rate', admin, rows.find { |r| r[:id].nil? }[:cell])).to include(total_count: 1, total_cents: 50_000)
    end

    it 'starts an employee on products, their own deals only' do
      result = run('win_rate', agent)
      expect(result[:group_by]).to eq('product')
      expect(result[:totals]).to include(won_count: 2, lost_count: 1)
    end
  end

  describe SalesCrm::Reports::Losses do
    let(:rival) { item('competitor', 'المنافس') }

    def moved_to_lost(target_deal, from)
      account.crm_activities.create!(deal: target_deal, kind: 'stage_changed', data: { from_stage_id: from.id, to_stage_id: pipeline.lost_stage.id })
    end

    before do
      moved_to_lost(lost(100_000, riyadh.local(2026, 10, 3), 'السعر', competitor_id: rival.id), stage(25))
      lost(200_000, riyadh.local(2026, 10, 4), 'سعر', assignee: colleague) # no move logged: stage unknown
      moved_to_lost(lost(300_000, riyadh.local(2026, 10, 5), 'التوقيت', competitor_id: rival.id), stage(75))
    end

    it 'groups the lost deals by reason, competitor and the stage they were lost in' do
      result = run('losses', admin)
      expect(result[:totals]).to eq(count: 3, total_cents: 600_000)
      expect(result[:reasons].map { |r| [r[:name], r[:count], r[:total_cents]] }).to eq([['السعر', 2, 300_000], ['التوقيت', 1, 300_000]])
      expect(result[:competitors].map { |r| [r[:name], r[:count]] }).to eq([['المنافس', 2], [nil, 1]])
      expect(result[:stages].map { |r| [r[:key], r[:total_cents]] }).to contain_exactly([stage(25).id.to_s, 100_000],
                                                                                        ['unknown', 200_000], [stage(75).id.to_s, 300_000])
    end

    it 'opens the deals behind each group' do
      expect(drill('losses', admin, { from_stage_id: 'unknown' })).to include(total_count: 1, total_cents: 200_000)
      expect(drill('losses', admin, { competitor_id: rival.id })).to include(total_count: 2, total_cents: 400_000)
      expect(drill('losses', admin, { reason: SalesCrm::Normalize.loose('السعر') })).to include(total_count: 2)
      expect(run('losses', agent)[:totals]).to eq(count: 2, total_cents: 400_000)
    end
  end

  describe SalesCrm::Reports::Activity do
    before do
      task = ->(user, kind, at) { create(:crm_task, account: account, assignee: user, kind: kind, status: :done, done_at: at) }
      2.times { task.call(agent, :call, riyadh.local(2026, 10, 5)) }
      task.call(agent, :meeting, riyadh.local(2026, 10, 6))
      task.call(colleague, :task, riyadh.local(2026, 10, 7))
      task.call(agent, :call, riyadh.local(2026, 9, 25)) # the period before: 11–30 September
      account.crm_notes.create!(deal: deal, user: agent, content: 'تمت المتابعة', created_at: riyadh.local(2026, 10, 10))
      won(100_000, riyadh.local(2026, 10, 8))
    end

    it 'counts each employee completed tasks by kind and notes, beside their results' do
      result = run('activity', admin)
      mine = result[:assignees].find { |r| r[:assignee_id] == agent.id }
      expect(mine).to include(by_kind: { 'task' => 0, 'call' => 2, 'meeting' => 1 }, note_count: 1, activity_count: 4,
                              won_count: 1, won_cents: 100_000, win_rate: 100.0)
      expect(result[:totals][:activity_count]).to eq(5)
      expect(result[:previous_totals][:activity_count]).to eq(1)
    end

    it 'opens the tasks behind a count' do
      expect(drill('activity', admin, { kind: 'call', assignee_id: agent.id })).to include(type: 'tasks', total_count: 2)
    end
  end

  describe SalesCrm::Reports::NewDeals do
    let(:web) { item('lead_source', 'الموقع') }

    before do
      deal(amount_cents: 100_000, lead_source_id: web.id, created_at: riyadh.local(2026, 10, 3, 9))
      deal(amount_cents: 200_000, lead_source_id: web.id, assignee: colleague, created_at: riyadh.local(2026, 10, 3, 22))
      deal(amount_cents: 50_000, created_at: riyadh.local(2026, 10, 15))
      deal(amount_cents: 70_000, created_at: riyadh.local(2026, 9, 20)) # the period before
    end

    it 'counts the deals created by source and over the period' do
      result = run('new_deals', admin)
      expect(result[:totals]).to eq(count: 3, total_cents: 350_000)
      expect(result[:previous_totals]).to eq(count: 1, total_cents: 70_000)
      expect(result[:sources].map { |s| [s[:name], s[:count], s[:total_cents]] }).to eq([['الموقع', 2, 300_000], [nil, 1, 50_000]])
      third = result[:buckets].find { |b| b[:bucket] == '2026-10-03' }
      expect(third).to include(count: 2, total_cents: 300_000)
      expect(drill('new_deals', admin, third[:cell])).to include(total_count: 2, total_cents: 300_000)
      expect(drill('new_deals', admin, { lead_source_id: 'none' })).to include(total_count: 1, total_cents: 50_000)
    end

    it 'splits each employee new deals by source' do
      mine = run('new_deals', admin)[:assignees].find { |r| r[:assignee_id] == agent.id }
      expect(mine[:sources].map { |s| [s[:lead_source_id], s[:count]] }).to contain_exactly([web.id, 1], [nil, 1])
    end
  end

  describe SalesCrm::Reports::DataQuality do
    before do
      deal(close_date: Date.new(2026, 10, 30)) # complete and fresh
      deal(amount_cents: 0)
      deal(close_date: nil)
      deal(close_date: Date.new(2026, 10, 10)) # already past
      deal(assignee: nil)
      deal(last_activity_at: riyadh.local(2026, 9, 1)) # quiet for 49 days
      won(100_000, riyadh.local(2026, 10, 5), close_date: nil) # closed: not counted
    end

    it 'gives the share of complete open deals, and lists what each incomplete one lacks' do
      result = run('data_quality', admin)
      # complete = amount, close date and owner: 3 of 6 = 50.0%
      expect(result[:totals]).to include(open_count: 6, complete_count: 3, rate: 50.0, to_fix: 5,
                                         issues: { 'no_amount' => 1, 'no_close_date' => 1, 'past_close_date' => 1,
                                                   'no_owner' => 1, 'stale' => 1 })
      expect(result[:rows].map { |r| r[:issues] }).to contain_exactly(['no_amount'], ['no_close_date'], ['past_close_date'],
                                                                      ['no_owner'], ['stale'])
      expect(drill('data_quality', admin, { issue: 'no_owner' })[:total_count]).to eq(1)
    end

    it 'gives an employee their own deals to fix' do
      expect(run('data_quality', agent)[:totals]).to include(open_count: 5, to_fix: 4)
    end
  end

  describe SalesCrm::Reports::Scorecard do
    before do
      target(agent, 3_000_000)
      target(colleague, 1_000_000)
      won(1_500_000, riyadh.local(2026, 10, 5)) # created 10 days before
      lost(500_000, riyadh.local(2026, 10, 6))
      won(1_000_000, riyadh.local(2026, 10, 6), assignee: colleague)
      deal(amount_cents: 3_000_000, close_date: Date.new(2026, 10, 28), created_at: riyadh.local(2026, 10, 2))
    end

    it 'gives each employee a card and the team its average' do
      result = run('scorecard', admin)
      mine = result[:cards].find { |c| c[:assignee_id] == agent.id }
      # 1,500,000 of 3,000,000; 1 of 2 closed; 3,000,000 open ÷ 1,500,000 left
      expect(mine).to include(attainment: 50.0, win_rate: 50.0, coverage: 2.0, sales_cycle: 10.0, average_deal_cents: 1_500_000,
                              new_deal_count: 1, completeness: 100.0)
      expect(result[:cards].find { |c| c[:assignee_id] == colleague.id }).to include(attainment: 100.0, coverage: nil, completeness: nil)
      # the coverage and completeness averages are the agent's alone: the colleague has nothing to divide
      expect(result[:team_average]).to include(attainment: 75.0, win_rate: 75.0, coverage: 2.0, average_deal_cents: 1_250_000,
                                               new_deal_count: 0.5, completeness: 100.0)
      expect(result[:team_size]).to eq(2)
    end

    it 'shows the picked employee beside the team, and an employee their own card only' do
      picked = run('scorecard', admin, assignee_id: colleague.id.to_s)
      expect(picked[:cards].map { |c| c[:assignee_id] }).to eq([colleague.id])
      expect(picked[:team_average][:attainment]).to eq(75.0)
      own = run('scorecard', agent)
      expect(own[:cards].map { |c| c[:assignee_id] }).to eq([agent.id])
      expect(own[:team_average]).to be_nil
    end
  end
end
