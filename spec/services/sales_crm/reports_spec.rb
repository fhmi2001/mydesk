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
                             .perform(title: title, amount: amount, pipeline_id: pipeline.id, assignee_id: assignee.id)
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

  it 'funnel counts deals that reached each stage' do
    rows = SalesCrm::Reports::Funnel.new(account: account, user: admin, from: from, to: to).perform
    by_name = rows.to_h { |r| [r[:name], r[:reached_count]] }
    expect(by_name['عميل محتمل']).to eq(5)
    expect(by_name['مؤهل']).to eq(1)
    expect(by_name['مكسوبة']).to eq(2)
    expect(by_name['خاسرة']).to eq(2)
    expect(rows[1][:conversion_from_previous]).to eq(20.0)
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
