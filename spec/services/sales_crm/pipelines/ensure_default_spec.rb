# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SalesCrm::Pipelines::EnsureDefault do
  let(:account) { create(:account) }

  it 'creates the default pipeline once with six stages in order and their colors' do
    first = described_class.call(account)
    second = described_class.call(account)

    expect(second).to eq(first)
    expect(account.crm_pipelines.count).to eq(1)
    expect(first.name).to eq('المبيعات')
    expect(first.currency).to eq('SAR')
    expect(first.stages.map { |s| [s.name, s.probability, s.kind, s.color] }).to eq([
                                                                                      ['عميل محتمل', 10, 'open', '#94a3b8'],
                                                                                      ['مؤهل', 25, 'open', '#60a5fa'],
                                                                                      ['تم إرسال العرض', 50, 'open', '#a78bfa'],
                                                                                      ['تفاوض', 75, 'open', '#f59e0b'],
                                                                                      ['مكسوبة', 100, 'won', '#22c55e'],
                                                                                      ['خاسرة', 0, 'lost', '#ef4444']
                                                                                    ])
  end

  it 'uses the account default currency when set' do
    account.update!(crm_default_currency: 'AED')
    expect(described_class.call(account).currency).to eq('AED')
  end

  it 'returns the existing pipeline when any exists' do
    existing = create(:crm_pipeline, account: account, name: 'Other')
    expect(described_class.call(account)).to eq(existing)
  end
end
