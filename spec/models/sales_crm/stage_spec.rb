# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SalesCrm::Stage do
  let(:account) { create(:account) }
  let(:pipeline) { create(:crm_pipeline, account: account) }

  it 'rejects a probability above 100' do
    stage = build(:crm_stage, pipeline: pipeline, probability: 101)
    expect(stage).not_to be_valid
  end

  it 'allows only one won stage per pipeline (database level)' do
    expect { pipeline.stages.create!(account: account, name: 'x', kind: :won, probability: 100) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'allows only one lost stage per pipeline (database level)' do
    expect { pipeline.stages.create!(account: account, name: 'x', kind: :lost, probability: 0) }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'defaults the color by kind' do
    stage = pipeline.stages.create!(account: account, name: 'y', kind: :open, probability: 5, color: '')
    expect(stage.color).to eq('#94a3b8')
  end
end
