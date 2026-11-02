# Custom (MyDesk): phase 1 of the sales reports (docs/reports/gap-analysis.md): managed lists, the new deal fields,
# the required-field rules, one currency, the close-date log, monthly targets and task kinds
require 'rails_helper'

RSpec.describe 'Sales CRM report fields' do # rubocop:disable RSpec/DescribeClass
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:lead) { pipeline.first_open_stage }
  let(:qualified) { pipeline.stages.find { |s| s.name == 'مؤهل' } }
  let(:close_date) { Date.current + 20 }

  def create_deal(user: agent, **attrs)
    SalesCrm::Deals::Create.new(account: account, user: user)
                           .perform({ title: 'باقة', amount: '1000', close_date: close_date, pipeline_id: pipeline.id }.merge(attrs))
  end

  def update_deal(deal, user: agent, **attrs)
    SalesCrm::Deals::Update.new(account: account, user: user).perform(deal, attrs)
  end

  def item(list, name)
    SalesCrm::ListItem.create!(account: account, list: list, name: name)
  end

  describe SalesCrm::ListItem do
    it 'keeps one active name per list, case-insensitively, and frees it once archived' do
      first = item('product', 'Gold')
      expect { item('product', 'gold') }.to raise_error(ActiveRecord::RecordInvalid)
      expect(item('competitor', 'Gold')).to be_persisted
      first.archive!
      expect(item('product', 'Gold')).to be_persisted
      expect(described_class.for_list(account, 'product').map(&:name)).to eq(['Gold'])
    end

    it 'rejects an unknown list' do
      expect { item('colour', 'x') }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'deal list fields' do
    it 'stores each list value and refuses one from another list or account' do
      source = item('lead_source', 'إحالة')
      product = item('product', 'باقة ذهبية')
      deal = create_deal(lead_source_id: source.id, product_id: product.id)
      expect([deal.lead_source, deal.product]).to eq([source, product])

      expect { create_deal(product_id: source.id) }.to raise_error(SalesCrm::ValidationError)
      foreign = SalesCrm::ListItem.create!(account: create(:account), list: 'product', name: 'x')
      expect { update_deal(deal, product_id: foreign.id) }.to raise_error(SalesCrm::ValidationError)
    end
  end

  describe 'probability and forecast category' do
    it 'uses the stage probability until overridden, and the stage again after a move' do
      deal = create_deal
      expect(deal.effective_probability).to eq(10)
      update_deal(deal, probability_override: 60)
      expect(deal.reload.effective_probability).to eq(60)
      SalesCrm::Deals::Move.new(account: account, user: agent).perform(deal, stage_id: qualified.id)
      expect(deal.reload.probability_override).to be_nil
      expect(deal.effective_probability).to eq(25)
    end

    it 'derives the forecast category from the probability unless the employee picked one' do
      deal = create_deal
      expect(deal.effective_forecast_category).to eq('pipeline')
      update_deal(deal, probability_override: 55)
      expect(deal.reload.effective_forecast_category).to eq('best_case')
      update_deal(deal, probability_override: 95)
      expect(deal.reload.effective_forecast_category).to eq('commit')
      update_deal(deal, forecast_category: 'omitted')
      expect(deal.reload.effective_forecast_category).to eq('omitted')
      expect { update_deal(deal, forecast_category: 'maybe') }.to raise_error(SalesCrm::ValidationError)
    end

    it 'weights the forecast with the deal probability' do
      deal = create_deal(amount: '1000')
      update_deal(deal, probability_override: 50)
      forecast = SalesCrm::Forecast.call(account.crm_deals.kept, pipeline: pipeline)
      expect(forecast.expected_cents).to eq(50_000)
    end
  end

  describe 'required fields for an open deal' do
    it 'needs an amount above zero and an expected close date, on create and on edit' do
      expect { create_deal(amount: '0') }.to raise_error(SalesCrm::ValidationError)
      expect { create_deal(close_date: nil) }.to raise_error(SalesCrm::ValidationError)
      deal = create_deal
      expect { update_deal(deal, close_date: nil) }.to raise_error(SalesCrm::ValidationError)
      expect { update_deal(deal, amount: '0') }.to raise_error(SalesCrm::ValidationError)
    end

    it 'does not hold back a deal created straight into won or lost, or a move of an old incomplete deal' do
      expect(create_deal(close_date: nil, stage_id: pipeline.won_stage.id)).to be_won
      old = create(:crm_deal, account: account, pipeline: pipeline, stage: lead, close_date: nil, assignee: agent)
      SalesCrm::Deals::Move.new(account: account, user: agent).perform(old, stage_id: qualified.id)
      expect(old.reload.stage).to eq(qualified)
    end

    it 'gives a new deal its creator as owner and never leaves an open deal without one' do
      expect(create_deal.assignee).to eq(agent)
      deal = create_deal(user: admin, assignee_id: agent.id)
      expect(deal.assignee).to eq(agent)
      expect { update_deal(deal, user: admin, assignee_id: nil) }.to raise_error(SalesCrm::ValidationError)
    end
  end

  describe 'activity' do
    it 'logs close date changes and moves last_activity_at with every Sales activity' do
      deal = travel_to(2.days.ago) { create_deal }
      expect(deal.last_activity_at).to be_within(1.minute).of(2.days.ago)
      update_deal(deal, close_date: close_date + 5)
      log = deal.activities.find_by(kind: 'close_date_changed')
      expect(log.data).to include('from' => close_date.iso8601, 'to' => (close_date + 5).iso8601)
      expect(deal.reload.last_activity_at).to be_within(1.minute).of(Time.current)
    end
  end

  describe 'currency' do
    it 'comes from the Sales settings, for new pipelines and their deals' do
      account.update!(crm_default_currency: 'AED')
      created = SalesCrm::Pipelines::Create.new(account: account, user: admin).perform(name: 'B2B', currency: 'USD')
      expect(created.currency).to eq('AED')
    end

    it 'can change only while the account has no deals, and then moves every pipeline with it' do
      pipeline # exists before the change
      expect(SalesCrm::Currency.change!(account, 'aed')).to eq('AED')
      expect(pipeline.reload.currency).to eq('AED')
      create_deal
      expect { SalesCrm::Currency.change!(account, 'USD') }.to raise_error(SalesCrm::ValidationError)
    end
  end

  describe SalesCrm::Target do
    it 'keeps one monthly target per employee and sums the team from them' do
      SalesCrm::Targets::Set.new(account: account, user: admin)
                            .perform(month: '2026-11', amounts: { agent.id => '50000', admin.id => '20000.50' })
      SalesCrm::Targets::Set.new(account: account, user: admin).perform(month: '2026-11', amounts: { agent.id => '60000' })
      november = account.crm_targets.where(period_start: Date.new(2026, 11, 1))
      expect(november.count).to eq(2)
      expect(november.find_by(user: agent)).to have_attributes(amount_cents: 6_000_000, period_end: Date.new(2026, 11, 30))
      # 60,000.00 + 20,000.50
      expect(described_class.team_cents(account, Date.new(2026, 11, 1)..Date.new(2026, 11, 30))).to eq(8_000_050)
    end

    it 'refuses a target for someone outside the account' do
      expect do
        SalesCrm::Targets::Set.new(account: account, user: admin).perform(month: '2026-11', amounts: { create(:user).id => '1' })
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'task kind' do
    it 'is a task unless it is a call or a meeting' do
      task = SalesCrm::Tasks::Create.new(account: account, user: agent).perform(title: 'اتصل', kind: 'call')
      expect(task).to be_call
      expect(SalesCrm::Tasks::Create.new(account: account, user: agent).perform(title: 'x')).to be_task
      expect { SalesCrm::Tasks::Create.new(account: account, user: agent).perform(title: 'x', kind: 'email') }
        .to raise_error(SalesCrm::ValidationError)
    end
  end
end
