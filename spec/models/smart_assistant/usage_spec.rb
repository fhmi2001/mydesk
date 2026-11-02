require 'rails_helper'

RSpec.describe SmartAssistant::Usage do
  let(:account) { create(:account) }

  before do
    described_class.create!(account: account, kind: :reply, model: 'gpt-6-luna', input_tokens: 900, output_tokens: 60, cost: 0.00012)
    described_class.create!(account: account, kind: :reply, model: 'gpt-6-luna', input_tokens: 1100, output_tokens: 40, cost: 0.00013)
    described_class.create!(account: account, kind: :knowledge, model: 'text-embedding-3-small', input_tokens: 500, cost: 0.00001)
    described_class.create!(account: account, kind: :reply, model: 'gpt-6-luna', input_tokens: 10, cost: 0.1, created_at: 2.months.ago)
  end

  it 'sums tokens and cost per kind' do
    totals = described_class.in_month(Time.current).totals_by_kind

    expect(totals['reply']).to include(input_tokens: 2000, output_tokens: 100, calls: 2, cost: BigDecimal('0.00025'))
    expect(totals['knowledge']).to include(input_tokens: 500, calls: 1)
    expect(totals).not_to have_key('test')
  end

  describe 'the Sales monthly limit (separate from the reply quota)' do
    before { allow(SmartAssistant::Config).to receive(:crm_monthly_limit).and_return(2) }

    def sales_call(kind, at = Time.current)
      described_class.create!(account: account, kind: kind, model: 'gpt-6-luna', created_at: at)
    end

    it 'counts only the Sales calls of this month' do
      sales_call(:crm_summary)
      sales_call(:crm_followup, 2.months.ago)
      expect(described_class.crm_calls_this_month(account)).to eq(1)
      expect(described_class.crm_limit_reached?(account)).to be(false)
    end

    it 'never counts toward the reply quota, which counts the assistant bot replies' do
      assistant = SmartAssistant.for_account(account).tap(&:save!)
      5.times { sales_call(:crm_summary) }
      expect(assistant.replies_this_month).to eq(0)
    end

    it 'is reached once the Sales calls hit the limit, whatever the replies' do
      sales_call(:crm_summary)
      sales_call(:crm_message)
      expect(described_class.crm_limit_reached?(account)).to be(true)
      expect(described_class.crm_limit_reached?(create(:account))).to be(false)
    end
  end

  it 'sums tokens and cost per month, oldest first' do
    months = described_class.where(account: account).totals_by_month

    expect(months.first).to include(month: 2.months.ago.beginning_of_month.to_date.iso8601, calls: 1)
    expect(months.last).to include(month: Time.current.beginning_of_month.to_date.iso8601, calls: 3, input_tokens: 2500)
  end
end
