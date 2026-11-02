# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SalesCrm::Pipeline do
  let(:account) { create(:account) }
  let(:pipeline) { create(:crm_pipeline, account: account) }

  it 'exposes won, lost and open stages in order' do
    expect(pipeline.won_stage.name).to eq('مكسوبة')
    expect(pipeline.lost_stage.name).to eq('خاسرة')
    expect(pipeline.open_stages.map(&:name)).to eq(['عميل محتمل', 'مؤهل', 'تم إرسال العرض', 'تفاوض'])
    expect(pipeline.first_open_stage.probability).to eq(10)
  end

  it 'locks the currency once a deal exists' do
    expect(pipeline.currency_locked?).to be(false)
    create(:crm_deal, account: account, pipeline: pipeline)
    pipeline.currency = 'USD'
    expect(pipeline).not_to be_valid
    expect(pipeline.errors[:currency]).to be_present
  end

  it 'rejects an unknown currency' do
    expect(build(:crm_pipeline, account: account, currency: 'XXX')).not_to be_valid
  end

  it 'requires a unique name per account' do
    create(:crm_pipeline, account: account, name: 'A', with_stages: false)
    expect(build(:crm_pipeline, account: account, name: 'A')).not_to be_valid
  end
end
