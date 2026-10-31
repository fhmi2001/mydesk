# Custom (MyDesk): pipeline services
require 'rails_helper'

RSpec.describe SalesCrm::Pipelines do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:pipeline) { SalesCrm::Pipelines::EnsureDefault.call(account) }

  def rows(pipeline)
    pipeline.stages.map { |s| { id: s.id, name: s.name, probability: s.probability, kind: s.kind, color: s.color } }
  end

  def deal_in(stage)
    SalesCrm::Deals::Create.new(account: account, user: user).perform(title: 'd', amount: '10', pipeline_id: pipeline.id, stage_id: stage.id)
  end

  describe SalesCrm::Pipelines::Update do
    let(:update) { described_class.new(account: account, user: user) }

    it 'removing a stage with deals and a target moves the deals' do
      qualified = pipeline.stages[1]
      lead = pipeline.stages[0]
      deal = deal_in(qualified)
      update.perform(pipeline, stages: rows(pipeline).reject { |r| r[:id] == qualified.id }, stage_moves: { qualified.id.to_s => lead.id })
      expect(deal.reload.stage).to eq(lead)
      expect(pipeline.stages.reload.size).to eq(5)
    end

    it 'removing a stage with deals and no target is refused and nothing changes' do
      qualified = pipeline.stages[1]
      deal_in(qualified)
      expect { update.perform(pipeline, stages: rows(pipeline).reject { |r| r[:id] == qualified.id }) }
        .to raise_error(SalesCrm::ValidationError)
      expect(pipeline.stages.reload.size).to eq(6)
    end

    it 'reorders, renames and adds stages' do
      new_rows = rows(pipeline)
      new_rows[0][:name] = 'جديد'
      new_rows.insert(1, { name: 'اتصال أول', probability: 15, kind: 'open', color: '#111111' })
      update.perform(pipeline, name: 'مبيعات التجزئة', stages: new_rows)
      pipeline.reload
      expect(pipeline.name).to eq('مبيعات التجزئة')
      expect(pipeline.stages.map(&:name)[0..2]).to eq(['جديد', 'اتصال أول', 'مؤهل'])
      expect(pipeline.stages.map(&:position)).to eq((0..6).to_a)
    end

    it 'refuses a currency change once deals exist' do
      deal_in(pipeline.stages[0])
      expect { update.perform(pipeline, currency: 'USD') }.to raise_error(SalesCrm::ValidationError)
    end

    it 'refuses a second won stage' do
      new_rows = rows(pipeline) + [{ name: 'x', probability: 100, kind: 'won' }]
      expect { update.perform(pipeline, stages: new_rows) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe SalesCrm::Pipelines::Destroy do
    let(:destroy) { described_class.new(account: account, user: user) }

    it 'refuses the last pipeline' do
      expect { destroy.perform(pipeline) }.to raise_error(SalesCrm::ValidationError)
    end

    it 'refuses a pipeline with deals' do
      other = SalesCrm::Pipelines::Create.new(account: account, user: user).perform(name: 'B')
      deal_in(pipeline.stages[0])
      expect(other).to be_persisted
      expect { destroy.perform(pipeline) }.to raise_error(SalesCrm::ValidationError)
    end

    it 'deletes an empty extra pipeline with its stages' do
      pipeline
      other = SalesCrm::Pipelines::Create.new(account: account, user: user).perform(name: 'B')
      destroy.perform(other)
      expect(SalesCrm::Stage.where(pipeline_id: other.id)).to be_empty
    end
  end
end
