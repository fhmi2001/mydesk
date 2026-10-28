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

  it 'sums tokens and cost per month, oldest first' do
    months = described_class.where(account: account).totals_by_month

    expect(months.first).to include(month: 2.months.ago.beginning_of_month.to_date.iso8601, calls: 1)
    expect(months.last).to include(month: Time.current.beginning_of_month.to_date.iso8601, calls: 3, input_tokens: 2500)
  end
end
