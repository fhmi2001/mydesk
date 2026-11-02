# Custom (MyDesk): phase 3 of docs/reports/CRM_REPORTS_PLAN.md. Each metric on a handful of deals, with the expected
# numbers worked out by hand in the comments, plus «—» (nil) wherever there is nothing to divide by.
require 'rails_helper'

RSpec.describe SalesCrm::Metrics do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:lead) { pipeline.stages.first } # 10%
  let(:qualified) { pipeline.stages.second } # 25%
  let(:october) { SalesCrm::Period.new(Date.new(2026, 10, 1), Date.new(2026, 10, 31)) }
  let(:deals) { account.crm_deals.kept }
  let(:riyadh) { ActiveSupport::TimeZone['Asia/Riyadh'] }

  def deal(attrs = {})
    create(:crm_deal, { account: account, pipeline: pipeline, stage: lead, assignee: agent }.merge(attrs))
  end

  def won(cents, at, created_at: at - 10.days, **attrs)
    deal(amount_cents: cents, status: :won, stage: pipeline.won_stage, won_at: at, created_at: created_at, **attrs)
  end

  def lost(cents, at)
    deal(amount_cents: cents, status: :lost, stage: pipeline.lost_stage, lost_at: at, lost_reason: 'x')
  end

  describe SalesCrm::Period do
    it 'defaults to this month so far, in Riyadh days, and knows the period before it' do
      travel_to riyadh.local(2026, 10, 20, 1, 0) do
        period = described_class.parse(nil, nil)
        expect([period.first, period.last]).to eq([Date.new(2026, 10, 1), Date.new(2026, 10, 20)])
        expect(period.begins_at).to eq(riyadh.local(2026, 10, 1))
        expect(period.previous).to eq(described_class.new(Date.new(2026, 9, 11), Date.new(2026, 9, 30)))
      end
    end

    it 'splits a period into the months it touches, with its days in each' do
      period = described_class.new(Date.new(2026, 10, 16), Date.new(2026, 11, 15))
      expect(period.month_overlaps).to eq([[Date.new(2026, 10, 1), 16, 31], [Date.new(2026, 11, 1), 15, 30]])
    end

    it 'always uses Riyadh, whatever the account reporting time zone says' do
      expect(SalesCrm::TimeZone.for(account).tzinfo.name).to eq('Asia/Riyadh')
    end
  end

  describe SalesCrm::Metrics::WeightedPipeline do
    it 'sums amount × probability over open deals, the deal own probability first' do
      deal(amount_cents: 100_000) # 10% → 10,000
      deal(amount_cents: 200_000, stage: qualified, probability_override: 60) # 60% → 120,000
      won(500_000, 1.day.ago) # closed: left out
      expect(described_class.call(deals)).to eq(130_000)
    end
  end

  describe SalesCrm::Metrics::Target do
    before do
      create(:crm_target, account: account, user: agent, period_start: Date.new(2026, 10, 1), amount_cents: 3_000_000)
      create(:crm_target, account: account, user: agent, period_start: Date.new(2026, 11, 1), amount_cents: 6_000_000)
      create(:crm_target, account: account, user: colleague, period_start: Date.new(2026, 10, 1), amount_cents: 1_000_000)
    end

    it 'takes whole months whole, and part of a month in proportion to its days' do
      expect(described_class.cents(account, october, user_ids: agent.id)).to eq(3_000_000)
      quarter = SalesCrm::Period.quarter(Date.new(2026, 10, 5))
      expect(described_class.cents(account, quarter, user_ids: agent.id)).to eq(9_000_000)
      # 16/31 of 3,000,000 = 1,548,387 and 15/30 of 6,000,000 = 3,000,000
      straddle = SalesCrm::Period.new(Date.new(2026, 10, 16), Date.new(2026, 11, 15))
      expect(described_class.cents(account, straddle, user_ids: agent.id)).to eq(4_548_387)
    end

    it 'gives the team the sum of its employees' do
      expect(described_class.cents(account, october)).to eq(4_000_000)
    end
  end

  describe SalesCrm::Metrics::QuotaAttainment do
    it 'divides the value won by the target, and is unknown without a target' do
      expect(described_class.call(won_cents: 1_500_000, target_cents: 3_000_000)).to eq(50.0)
      expect(described_class.call(won_cents: 1_000_000, target_cents: 3_000_000)).to eq(33.3)
      expect(described_class.call(won_cents: 1_000_000, target_cents: 0)).to be_nil
    end
  end

  describe SalesCrm::Metrics::PipelineCoverage do
    it 'divides the open value closing in the period by what is left of the target' do
      # 4,000,000 open ÷ (3,000,000 − 1,000,000) = 2.0
      expect(described_class.call(open_cents: 4_000_000, target_cents: 3_000_000, won_cents: 1_000_000)).to eq(2.0)
      expect(described_class.call(open_cents: 4_000_000, target_cents: 3_000_000, won_cents: 3_000_000)).to be_nil
      expect(described_class.call(open_cents: 4_000_000, target_cents: 0, won_cents: 0)).to be_nil
    end

    it 'counts only open deals expected to close inside the period' do
      deal(amount_cents: 300_000, close_date: Date.new(2026, 10, 31))
      deal(amount_cents: 700_000, close_date: Date.new(2026, 11, 1))
      expect(described_class.open_closing_cents(deals, october)).to eq(300_000)
    end
  end

  describe SalesCrm::Metrics::WinRate do
    it 'is won ÷ closed by count and by value, in Riyadh days' do
      won(100_000, riyadh.local(2026, 10, 1, 0, 30)) # 21:30 UTC on 30 Sep: still October in Riyadh
      won(200_000, riyadh.local(2026, 10, 15))
      won(300_000, riyadh.local(2026, 10, 31, 23, 0))
      lost(400_000, riyadh.local(2026, 10, 20))
      won(900_000, riyadh.local(2026, 11, 1, 0, 30)) # November in Riyadh
      result = described_class.call(deals, october)
      # 3 won of 4 closed = 75.0%; 600,000 won of 1,000,000 closed = 60.0%
      expect(result).to include(won_count: 3, lost_count: 1, won_cents: 600_000, lost_cents: 400_000, by_count: 75.0, by_value: 60.0)
    end

    it 'is unknown with no closed deal' do
      expect(described_class.call(deals, october)).to include(by_count: nil, by_value: nil)
    end
  end

  describe SalesCrm::Metrics::StageConversion do
    it 'gives the share that went on, unknown when the stage before had none' do
      expect(described_class.rate(2, 5)).to eq(40.0)
      expect(described_class.rate(0, 0)).to be_nil
      expect(described_class.rate(3, nil)).to be_nil
    end
  end

  describe SalesCrm::Metrics::SalesCycle do
    it 'averages the days from creation to the win, over the deals won in the period' do
      won(100_000, riyadh.local(2026, 10, 20), created_at: riyadh.local(2026, 10, 10)) # 10 days
      won(100_000, riyadh.local(2026, 10, 25), created_at: riyadh.local(2026, 10, 5)) # 20 days
      expect(described_class.call(deals, october)).to eq(15.0)
      expect(described_class.call(deals, october.previous)).to be_nil
    end
  end

  describe SalesCrm::Metrics::AverageDealSize do
    it 'averages the won value, leaving out won deals without an amount' do
      won(100_000, riyadh.local(2026, 10, 3))
      won(300_000, riyadh.local(2026, 10, 4))
      won(0, riyadh.local(2026, 10, 5))
      expect(described_class.call(deals, october)).to eq(200_000)
      expect(described_class.call(deals, october.previous)).to be_nil
    end
  end

  describe SalesCrm::Metrics::Slippage do
    let(:before_october) { riyadh.local(2026, 9, 1) }

    def changed(target, at, from, to)
      account.crm_activities.create!(deal: target, kind: 'close_date_changed', data: { from: from.iso8601, to: to.iso8601 }, created_at: at)
    end

    it 'counts the deals expected in the period whose date was pushed past it without closing' do
      travel_to riyadh.local(2026, 11, 10) do
        deal(close_date: Date.new(2026, 10, 15), created_at: before_october) # expected, kept its date
        pushed = deal(close_date: Date.new(2026, 11, 20), created_at: before_october) # expected, pushed: slipped
        changed(pushed, riyadh.local(2026, 10, 10), Date.new(2026, 10, 20), Date.new(2026, 11, 20))
        pulled_in = deal(close_date: Date.new(2026, 10, 25), created_at: before_october) # not expected at the start
        changed(pulled_in, riyadh.local(2026, 10, 5), Date.new(2026, 11, 10), Date.new(2026, 10, 25))
        closed = deal(close_date: Date.new(2026, 11, 5), created_at: before_october, status: :won, stage: pipeline.won_stage,
                      won_at: riyadh.local(2026, 10, 28)) # pushed, then won in October: not slipped
        changed(closed, riyadh.local(2026, 10, 12), Date.new(2026, 10, 18), Date.new(2026, 11, 5))
        deal(close_date: Date.new(2026, 10, 20), created_at: riyadh.local(2026, 10, 5)) # created later: not counted
        late = deal(close_date: Date.new(2026, 11, 30), created_at: before_october) # moved twice; past October only in November
        changed(late, riyadh.local(2026, 10, 3), Date.new(2026, 10, 9), Date.new(2026, 10, 30))
        changed(late, riyadh.local(2026, 11, 2), Date.new(2026, 10, 30), Date.new(2026, 11, 30))

        # expected: kept, pushed, closed, late = 4; slipped: pushed = 1 → 25.0%
        expect(described_class.call(account, deals, october)).to eq(expected_count: 4, slipped_count: 1, rate: 25.0)
      end
    end

    it 'is unknown when nothing was expected' do
      expect(described_class.call(account, deals, october)).to eq(expected_count: 0, slipped_count: 0, rate: nil)
    end
  end

  describe SalesCrm::Metrics::DaysSinceActivity do
    it 'counts Riyadh days since the last activity, else since creation' do
      today = Date.new(2026, 10, 20)
      active = deal(last_activity_at: Time.utc(2026, 10, 5, 22, 0)) # 01:00 on 6 Oct in Riyadh → 14 days
      quiet = deal(last_activity_at: nil, created_at: riyadh.local(2026, 10, 17)) # 3 days
      expect(described_class.call(active, today: today)).to eq(14)
      expect(described_class.call(quiet, today: today)).to eq(3)
      expect(described_class.stale(deals, 14, today: today)).to contain_exactly(active)
    end

    # Decision ح (CONVERSATION_SALES_PLAN.md): an employee's reply to the customer counts too
    it 'counts from the later of the last activity and the last reply in the conversation' do
      today = Date.new(2026, 10, 20)
      replied = deal(last_activity_at: riyadh.local(2026, 10, 1), last_message_at: riyadh.local(2026, 10, 18))
      expect(described_class.call(replied, today: today)).to eq(2)
      expect(described_class.stale(deals, 14, today: today)).not_to include(replied)
    end
  end

  describe SalesCrm::Metrics::DataCompleteness do
    it 'is the share of open deals with an amount, an expected close date and an owner' do
      deal
      deal(amount_cents: 0)
      deal(close_date: nil)
      deal(assignee: nil)
      won(100_000, 1.day.ago, close_date: nil) # closed: not counted
      # 1 complete of 4 open = 25.0%
      expect(described_class.call(deals)).to eq(open_count: 4, complete_count: 1, rate: 25.0)
      expect(described_class.incomplete(deals).count).to eq(3)
      expect(described_class.call(deals.none)).to include(rate: nil)
    end
  end
end
