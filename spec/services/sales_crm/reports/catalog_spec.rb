# Custom (MyDesk): docs/reports/CRM_REPORTS_PLAN.md, reports 1 to 7. A handful of deals per report,
# the expected numbers worked out by hand in the comments; the deals behind each number add up to it; an employee only
# ever gets their own. "Today" is 20 October 2026, 10:00 in Riyadh.
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

  def won(cents, at, assignee: agent)
    deal(amount_cents: cents, status: :won, stage: pipeline.won_stage, won_at: at, assignee: assignee)
  end

  def lost(cents, at, reason, assignee: agent)
    deal(amount_cents: cents, status: :lost, stage: pipeline.lost_stage, lost_at: at, lost_reason: reason, assignee: assignee)
  end

  def run(key, user, **filters) = SalesCrm::Reports::Catalog.fetch(key).new(account: account, user: user, **filters).perform
  def drill(key, user, cell, **filters) = SalesCrm::Reports::Catalog.fetch(key).new(account: account, user: user, cell: cell, **filters).drill

  describe SalesCrm::Reports::PipelineByStage do
    before do
      deal(amount_cents: 100_000) # 10% → 10,000
      deal(amount_cents: 200_000, stage: stage(25)) # 25% → 50,000
      deal(amount_cents: 400_000, stage: stage(25), probability_override: 60, assignee: colleague) # 60% → 240,000
      won(900_000, 1.day.ago)
    end

    it 'counts the open deals of each stage, split by employee for the manager' do
      result = run('pipeline_by_stage', admin)
      expect(result[:totals]).to include(count: 3, total_cents: 700_000, weighted_cents: 300_000)
      qualified = result[:rows].find { |r| r[:stage_id] == stage(25).id }
      expect(qualified).to include(count: 2, total_cents: 600_000, weighted_cents: 290_000)
      expect(qualified[:assignees].map { |a| [a[:assignee_id], a[:total_cents]] }).to eq([[colleague.id, 400_000], [agent.id, 200_000]])
      expect(result[:rows].map { |r| r[:count] }).to eq([1, 2, 0, 0])
      expect(result[:previous_period]).to be_nil
    end

    it 'lists the deals behind a number, and they add up to it' do
      cell = run('pipeline_by_stage', admin)[:rows].second[:assignees].first[:cell]
      expect(drill('pipeline_by_stage', admin, cell)).to include(total_count: 1, total_cents: 400_000)
    end

    it 'gives an employee their own deals only, whatever cell they ask for' do
      result = run('pipeline_by_stage', agent)
      expect(result).to include(team: false, assignees: nil)
      expect(result[:totals]).to include(count: 2, total_cents: 300_000)
      expect(drill('pipeline_by_stage', agent, { assignee_id: colleague.id })).to include(total_count: 2, total_cents: 300_000)
    end

    it 'filters on a managed list' do
      product = account.crm_list_items.create!(list: 'product', name: 'باقة')
      deal(amount_cents: 50_000, product_id: product.id)
      expect(run('pipeline_by_stage', admin, product_id: product.id.to_s)[:totals]).to include(count: 1, total_cents: 50_000)
    end
  end

  describe SalesCrm::Reports::Closing do
    it 'lists the open deals expected this month, soonest first, the whole month by default' do
      first = deal(amount_cents: 100_000, close_date: Date.new(2026, 10, 5)) # 10%, already late but in the month
      deal(amount_cents: 300_000, stage: stage(75), close_date: Date.new(2026, 10, 25)) # 75%
      deal(amount_cents: 900_000, close_date: Date.new(2026, 11, 2)) # next month
      result = run('closing', admin)
      expect(result[:period]).to eq(from: '2026-10-01', to: '2026-10-31')
      # 10,000 + 225,000 weighted; (10 + 75) ÷ 2 = 42.5%
      expect(result[:totals]).to eq(count: 2, total_cents: 400_000, weighted_cents: 235_000, average_probability: 42.5)
      expect(result[:rows].first[:id]).to eq(first.id)
      expect(result[:rows].first[:days_overdue]).to eq(15)
    end

    it 'lists every deal for a printout, not only the first ones' do
      stub_const('SalesCrm::Reports::Report::LIST_LIMIT', 1)
      2.times { |i| deal(close_date: Date.new(2026, 10, 25 + i)) }
      expect(run('closing', admin)[:rows].size).to eq(1)
      expect(run('closing', admin, full: 'true')[:rows].size).to eq(2)
    end

    it 'is empty, with no average, when nothing is expected' do
      expect(run('closing', agent)).to include(empty: true, totals: include(count: 0, average_probability: nil))
    end
  end

  describe SalesCrm::Reports::Stale do
    before do
      deal(amount_cents: 100_000, last_activity_at: riyadh.local(2026, 10, 1)) # 19 days quiet: stale
      deal(amount_cents: 200_000, last_activity_at: riyadh.local(2026, 10, 18), close_date: Date.new(2026, 10, 15)) # overdue
      deal(amount_cents: 300_000, last_activity_at: riyadh.local(2026, 10, 1), close_date: Date.new(2026, 10, 10)) # both
      deal(amount_cents: 400_000, last_activity_at: riyadh.local(2026, 10, 19)) # fine
    end

    it 'counts the stale and the overdue, and each deal once as at risk' do
      result = run('stale', admin)
      expect(result[:days]).to eq(14)
      expect(result[:totals]).to eq(stale: { count: 2, total_cents: 400_000 }, overdue: { count: 2, total_cents: 500_000 },
                                    at_risk: { count: 3, total_cents: 600_000 })
      # quietest first; the two quiet since 1 October by value
      expect(result[:rows].map { |r| r[:amount_cents] }).to eq([300_000, 100_000, 200_000])
      expect(result[:rows].first).to include(days_since_activity: 19, days_overdue: 10)
      expect(drill('stale', admin, { kind: 'stale' })).to include(total_count: 2, total_cents: 400_000)
    end

    it 'takes another number of quiet days' do
      expect(run('stale', admin, days: '30')[:totals][:stale][:count]).to eq(0)
    end

    it 'does not count a deal whose employee replied to the customer recently' do
      deal(amount_cents: 500_000, last_activity_at: riyadh.local(2026, 10, 1), last_message_at: riyadh.local(2026, 10, 19))
      expect(run('stale', admin)[:totals][:stale]).to eq(count: 2, total_cents: 400_000)
    end
  end

  describe SalesCrm::Reports::MyTasks do
    before do
      task = { account: account, assignee: agent }
      create(:crm_task, **task, kind: :call, due_at: riyadh.local(2026, 10, 19, 12)) # overdue
      create(:crm_task, **task, due_at: riyadh.local(2026, 10, 20, 9)) # earlier today: overdue
      create(:crm_task, **task, kind: :meeting, due_at: riyadh.local(2026, 10, 20, 18)) # later today
      create(:crm_task, **task, due_at: riyadh.local(2026, 10, 21, 9)) # tomorrow: not counted
      create(:crm_task, **task, status: :done, done_at: riyadh.local(2026, 10, 5)) # done this period (1–20 October)
      create(:crm_task, **task, status: :done, done_at: riyadh.local(2026, 9, 25)) # done in the one before (11–30 September)
      create(:crm_task, account: account, assignee: colleague, due_at: riyadh.local(2026, 10, 19)) # someone else's
    end

    it 'gives my overdue and due-today tasks, and what I finished against the period before' do
      result = run('my_tasks', agent)
      expect(result[:totals]).to eq(overdue_count: 2, today_count: 1, done_count: 1, by_kind: { 'task' => 1, 'call' => 1, 'meeting' => 1 })
      expect(result[:previous_totals]).to eq(done_count: 1)
      expect(result[:rows].size).to eq(3)
      expect(drill('my_tasks', agent, { kind: 'today' })[:total_count]).to eq(1)
    end

    it 'is the manager own list too, not the team' do
      expect(run('my_tasks', admin)).to include(empty: true, totals: include(overdue_count: 0))
    end
  end

  describe SalesCrm::Reports::WonLost do
    before do
      won(100_000, riyadh.local(2026, 10, 3))
      won(300_000, riyadh.local(2026, 10, 15), assignee: colleague)
      lost(200_000, riyadh.local(2026, 10, 10), 'السعر')
      lost(100_000, riyadh.local(2026, 10, 12), 'سعر', assignee: colleague) # the same reason, spelled without «ال»
      won(500_000, riyadh.local(2026, 9, 20)) # the period before: 11–30 September
      lost(50_000, riyadh.local(2026, 9, 25), 'x')
    end

    it 'counts what closed, by count and by value, against the period before' do
      result = run('won_lost', admin)
      # 2 of 4 = 50.0%; 400,000 of 700,000 = 57.1%
      expect(result[:totals]).to include(won_count: 2, lost_count: 2, won_cents: 400_000, lost_cents: 300_000, by_count: 50.0, by_value: 57.1)
      # 500,000 of 550,000 = 90.9%
      expect(result[:previous_totals]).to include(won_count: 1, lost_count: 1, by_value: 90.9)
      expect(result[:previous_period]).to eq(from: '2026-09-11', to: '2026-09-30')
      expect(result[:assignees].first).to include(assignee_id: colleague.id, won_cents: 300_000, lost_cents: 100_000)
    end

    it 'buckets by day, and each bucket opens its deals' do
      result = run('won_lost', admin)
      expect(result[:interval]).to eq('day')
      expect(result[:buckets].size).to eq(20)
      third = result[:buckets].find { |b| b[:bucket] == '2026-10-03' }
      expect(third).to include(won_count: 1, won_cents: 100_000)
      expect(drill('won_lost', admin, third[:cell].merge(status: 'won'))).to include(total_count: 1, total_cents: 100_000)
      # a bar opens both outcomes of its day: 10 October has the lost deal only
      tenth = result[:buckets].find { |b| b[:bucket] == '2026-10-10' }[:cell]
      expect(drill('won_lost', admin, tenth.merge(status: 'closed'))).to include(total_count: 1, total_cents: 200_000)
      expect(drill('won_lost', admin, { status: 'closed' })).to include(total_count: 4, total_cents: 700_000)
    end

    it 'merges spellings of a lost reason, and the reason opens its deals' do
      reason = run('won_lost', admin)[:lost_reasons].sole
      expect(reason).to include(count: 2, total_cents: 300_000)
      expect(drill('won_lost', admin, reason[:cell])).to include(total_count: 2, total_cents: 300_000)
    end
  end

  describe SalesCrm::Reports::Quota do
    before do
      create(:crm_target, account: account, user: agent, period_start: Date.new(2026, 10, 1), amount_cents: 3_000_000)
      create(:crm_target, account: account, user: colleague, period_start: Date.new(2026, 10, 1), amount_cents: 1_000_000)
      won(1_500_000, riyadh.local(2026, 10, 5))
      won(1_200_000, riyadh.local(2026, 10, 6), assignee: colleague)
    end

    it 'compares the month won with the month target, and ranks the employees' do
      result = run('quota', admin)
      # 2,700,000 of 4,000,000 = 67.5%
      expect(result[:totals]).to eq(won_count: 2, won_cents: 2_700_000, target_cents: 4_000_000, remaining_cents: 1_300_000, attainment: 67.5)
      expect(result[:previous_period]).to eq(from: '2026-09-01', to: '2026-09-30')
      expect(result[:previous_totals]).to include(target_cents: 0, attainment: nil)
      expect(result[:assignees].map { |r| [r[:assignee_id], r[:attainment], r[:rank]] }).to eq([[colleague.id, 120.0, 1], [agent.id, 50.0, 2]])
      expect(result[:assignees].first[:remaining_cents]).to eq(0)
    end

    it 'runs the value won day by day against the target spread over the month' do
      line = run('quota', admin)[:cumulative]
      expect(line.size).to eq(31)
      expect(line[4]).to include(date: '2026-10-05', won_cents: 1_500_000)
      expect(line[5][:won_cents]).to eq(2_700_000)
      expect(line[20][:won_cents]).to be_nil # 21 October is still to come
      expect([line.first[:target_cents], line.last[:target_cents]]).to eq([129_032, 4_000_000]) # 4,000,000 ÷ 31
    end

    it 'counts every pipeline against the target, whatever pipeline is asked for' do
      other = create(:crm_pipeline, account: account)
      expect(run('quota', admin, pipeline_id: other.id.to_s)[:totals]).to include(won_cents: 2_700_000)
    end

    it 'gives an employee their own target' do
      expect(run('quota', agent)[:totals]).to include(target_cents: 3_000_000, won_cents: 1_500_000, attainment: 50.0)
    end
  end

  describe SalesCrm::Reports::ForecastCategories do
    before do
      create(:crm_target, account: account, user: agent, period_start: Date.new(2026, 10, 1), amount_cents: 3_000_000)
      create(:crm_target, account: account, user: colleague, period_start: Date.new(2026, 10, 1), amount_cents: 2_000_000)
      october = { close_date: Date.new(2026, 10, 28) }
      deal(amount_cents: 400_000, stage: stage(75), **october) # 75%: best case
      deal(amount_cents: 200_000, probability_override: 90, **october) # 90%: commit
      deal(amount_cents: 50_000, stage: stage(25), forecast_category: :commit, **october) # picked: commit
      deal(amount_cents: 300_000, assignee: colleague, **october) # 10%: pipeline
      deal(amount_cents: 100_000, assignee: colleague, forecast_category: :omitted, **october)
      deal(amount_cents: 999_000, probability_override: 95) # November
      won(1_000_000, riyadh.local(2026, 10, 2))
    end

    it 'puts the deals closing this month in their categories, and forecasts won + commit against the target' do
      totals = run('forecast', admin)[:totals]
      expect(totals[:categories].transform_values { |c| c[:total_cents] }).to eq(pipeline: 300_000, best_case: 400_000, commit: 250_000,
                                                                                 omitted: 100_000)
      # 1,000,000 + 250,000 = 1,250,000 of 5,000,000 = 25.0%; best case adds 400,000
      expect(totals).to include(won_cents: 1_000_000, forecast_cents: 1_250_000, best_case_cents: 1_650_000, target_cents: 5_000_000,
                                forecast_attainment: 25.0, gap_cents: 3_750_000)
      # 30,000,000 + 18,000,000 + 1,250,000 + 3,000,000 raw (omitted left out) ÷ 100
      expect(totals[:weighted_cents]).to eq(522_500)
    end

    it 'forecasts each employee against their own target, and opens the deals of a category' do
      result = run('forecast', admin)
      mine = result[:assignees].find { |r| r[:assignee_id] == agent.id }
      expect(mine).to include(forecast_cents: 1_250_000, target_cents: 3_000_000, forecast_attainment: 41.7)
      expect(result[:assignees].find { |r| r[:assignee_id] == colleague.id }).to include(forecast_cents: 0, forecast_attainment: 0.0)
      expect(drill('forecast', admin, mine[:categories][:commit][:cell])).to include(total_count: 2, total_cents: 250_000)
      expect(drill('forecast', admin, mine[:won_cell])).to include(total_count: 1, total_cents: 1_000_000)
    end
  end

  # Custom (MyDesk): the time zone picked in the general settings (account.reporting_timezone)
  describe "the account's time zone" do
    before do
      account.update!(reporting_timezone: 'Asia/Dubai')
      # 23:30 on 30 September in Riyadh is 00:30 on 1 October in Dubai
      won(100_000, riyadh.local(2026, 9, 30, 23, 30))
      won(200_000, riyadh.local(2026, 10, 10, 12))
    end

    it 'puts a deal in the month of its day in that time zone' do
      october = run('won_lost', admin, from: '2026-10-01', to: '2026-10-31')
      expect(october[:totals]).to include(won_count: 2, won_cents: 300_000)
      expect(october[:previous_totals]).to include(won_count: 0)
      expect(drill('won_lost', admin, { status: 'won' }, from: '2026-10-01', to: '2026-10-31')).to include(total_count: 2)
    end
  end
end
