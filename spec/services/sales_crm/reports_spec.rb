# Custom (MyDesk): sales reports
require 'rails_helper'

RSpec.describe SalesCrm::Reports do
  let(:account) { create(:account, settings: { 'reporting_timezone' => 'Asia/Riyadh' }) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { SalesCrm::Pipelines::EnsureDefault.call(account) }
  let(:from) { '2026-10-01' }
  let(:to) { '2026-10-31' }

  def make(title, amount, assignee, created_at: Time.utc(2026, 10, 5))
    travel_to(created_at) do
      SalesCrm::Deals::Create.new(account: account, user: admin)
                             .perform(title: title, amount: amount, close_date: Date.new(2026, 10, 30), pipeline_id: pipeline.id,
                                      assignee_id: assignee.id)
    end
  end

  def move(deal, stage, at:, reason: nil)
    travel_to(at) { SalesCrm::Deals::Move.new(account: account, user: admin).perform(deal, stage_id: stage.id, lost_reason: reason) }
  end

  before do
    qualified = pipeline.stages[1]
    won = pipeline.won_stage
    lost = pipeline.lost_stage
    a = make('a', '1000', admin)
    move(a, qualified, at: Time.utc(2026, 10, 6))
    move(a, won, at: Time.utc(2026, 10, 10))
    b = make('b', '3000', agent)
    move(b, won, at: Time.utc(2026, 10, 20))
    c = make('c', '500', agent)
    move(c, lost, at: Time.utc(2026, 10, 15), reason: 'سعر مرتفع')
    d = make('d', '700', admin)
    move(d, lost, at: Time.utc(2026, 10, 16), reason: 'السعر مرتفع')
    make('e', '2000', agent) # still open, lead 10%
    old = make('old', '9000', admin, created_at: Time.utc(2026, 9, 10))
    move(old, won, at: Time.utc(2026, 9, 12))
  end

  it 'summary: won and lost counts, totals and win rate' do
    cur = SalesCrm::Reports::Summary.new(account: account, user: admin, from: from, to: to).perform[:current]
    expect(cur).to include(won_count: 2, lost_count: 2, win_rate: 50.0, won_total_cents: 400_000, lost_total_cents: 120_000)
  end

  it 'summary: open numbers, average days, previous window and currency' do
    r = SalesCrm::Reports::Summary.new(account: account, user: admin, from: from, to: to).perform
    expect(r[:current]).to include(open_count: 1, expected_cents: 20_000, avg_days_to_close: 10.0)
    expect(r[:previous][:won_count]).to eq(1)
    expect(r[:currency]).to eq('SAR')
  end

  it 'summary limits an agent to their own deals' do
    cur = SalesCrm::Reports::Summary.new(account: account, user: agent, from: from, to: to).perform[:current]
    expect(cur[:won_count]).to eq(1)
    expect(cur[:lost_count]).to eq(1)
  end

  it 'never gives an agent team numbers: not by asking for another assignee, not with the own-deals setting off' do
    account.update!(crm_agents_see_own_deals_only: false)
    cur = SalesCrm::Reports::Summary.new(account: account, user: agent, from: from, to: to, assignee_id: admin.id).perform[:current]
    expect(cur).to include(won_count: 1, lost_count: 1)
    rows = SalesCrm::Reports::Agents.new(account: account, user: agent, from: from, to: to).perform
    expect(rows.map { |r| r[:user_id] }).to eq([agent.id])
  end

  it 'funnel counts deals that reached each stage, skipped open stages included' do
    rows = SalesCrm::Reports::Funnel.new(account: account, user: admin, from: from, to: to).perform
    by_name = rows.to_h { |r| [r[:name], r[:reached_count]] }
    # a: lead > qualified > won; b: lead > won (skips every open stage); c, d: lead > lost; e: lead
    expect(by_name).to eq('عميل محتمل' => 5, 'مؤهل' => 2, 'تم إرسال العرض' => 2, 'تفاوض' => 2, 'مكسوبة' => 2, 'خاسرة' => 2)
    expect(rows.map { |r| r[:conversion_from_previous] }.first(3)).to eq([nil, 40.0, 100.0])
  end

  it 'funnel counts a deal once per stage when it jumps ahead and comes back, and never rises stage to stage' do
    f = make('f', '100', admin)
    move(f, pipeline.stages[3], at: Time.utc(2026, 10, 7))
    move(f, pipeline.stages[0], at: Time.utc(2026, 10, 8))
    rows = SalesCrm::Reports::Funnel.new(account: account, user: admin, from: from, to: to).perform
    by_name = rows.to_h { |r| [r[:name], r[:reached_count]] }
    expect(by_name['عميل محتمل']).to eq(6)
    expect(by_name['مؤهل']).to eq(3)
    expect(by_name['تفاوض']).to eq(3)
    open_counts = rows.select { |r| r[:kind] == 'open' }.map { |r| r[:reached_count] }
    expect(open_counts).to eq(open_counts.sort.reverse)
    expect(rows.filter_map { |r| r[:conversion_from_previous] }).to all(be <= 100)
  end

  it 'stage win rates: share of closed deals that reached each open stage and were won' do
    stub_const('SalesCrm::Reports::StageWinRates::MIN_CLOSED', 2)
    rows = SalesCrm::Reports::StageWinRates.new(account: account, user: admin, from: from, to: to, pipeline_id: pipeline.id).perform
    by_name = rows.to_h { |r| [pipeline.stages.find { |s| s.id == r[:stage_id] }.name, r.slice(:closed_count, :won_count, :win_rate)] }
    # closed in the period: a (lead > qualified > won), b (lead > won), c and d (lead > lost); e is still open
    expect(by_name['عميل محتمل']).to eq(closed_count: 4, won_count: 2, win_rate: 50.0)
    expect(by_name['مؤهل']).to eq(closed_count: 2, won_count: 2, win_rate: 100.0)
    expect(by_name.keys).not_to include('مكسوبة', 'خاسرة')
  end

  it 'stage win rates stay empty until enough deals have closed' do
    rows = SalesCrm::Reports::StageWinRates.new(account: account, user: admin, from: from, to: to, pipeline_id: pipeline.id).perform
    expect(rows.first).to include(closed_count: 4, win_rate: nil, min_closed: 20)
  end

  it 'agents report has a row per user' do
    rows = SalesCrm::Reports::Agents.new(account: account, user: admin, from: from, to: to).perform
    agent_row = rows.find { |r| r[:user_id] == agent.id }
    expect(agent_row[:won_count]).to eq(1)
    expect(agent_row[:lost_count]).to eq(1)
    expect(agent_row[:open_count]).to eq(1)
    expect(agent_row[:win_rate]).to eq(50.0)
  end

  it 'lost reasons merge spelling variants' do
    rows = SalesCrm::Reports::LostReasons.new(account: account, user: admin, from: from, to: to).perform
    expect(rows.size).to eq(1)
    expect(rows.first[:count]).to eq(2)
    expect(rows.first[:total_cents]).to eq(120_000)
  end

  it 'timeline buckets by month and by day' do
    monthly = SalesCrm::Reports::Timeline.new(account: account, user: admin, from: '2026-09-01', to: to).perform(interval: 'month')
    expect(monthly.map { |b| b[:bucket] }).to eq(%w[2026-09-01 2026-10-01])
    expect(monthly.last[:won]).to eq(2)
    expect(monthly.first[:won_total_cents]).to eq(900_000)
    daily = SalesCrm::Reports::Timeline.new(account: account, user: admin, from: from, to: to).perform(interval: 'day')
    expect(daily.size).to eq(31)
    expect(daily.find { |b| b[:bucket] == '2026-10-15' }[:lost]).to eq(1)
  end

  it 'export headers follow the locale' do
    csv = I18n.with_locale(:ar) { SalesCrm::Reports::Export.new(account: account, user: admin, from: from, to: to).perform }
    expect(csv.lines.first).to start_with('العنوان,القيمة,العملة')
    expect(csv.lines.size).to eq(6)
    en = I18n.with_locale(:en) { SalesCrm::Reports::Export.new(account: account, user: admin, from: from, to: to).perform }
    expect(en.lines.first).to start_with('Title,Amount,Currency')
  end

  it 'export neutralises spreadsheet formulas in free text' do
    contact = create(:contact, account: account, name: '=HYPERLINK("http://x")')
    deal = make('+SUM(1)', '10', admin)
    deal.update!(contact: contact)
    csv = I18n.with_locale(:en) { SalesCrm::Reports::Export.new(account: account, user: admin, from: from, to: to).perform }
    expect(csv).to include("'+SUM(1)")
    expect(csv).to include(%q("'=HYPERLINK(""http://x"")"))
    expect(SalesCrm::Reports::Export.safe_cell('-5')).to eq("'-5")
    expect(SalesCrm::Reports::Export.safe_cell('plain')).to eq('plain')
  end
end
