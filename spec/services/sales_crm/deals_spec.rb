# Custom (MyDesk): deal services
require 'rails_helper'

RSpec.describe SalesCrm::Deals do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:qualified) { pipeline.stages.find { |s| s.name == 'مؤهل' } }
  let(:lost) { pipeline.lost_stage }
  let(:won) { pipeline.won_stage }

  def create_deal(attrs = {})
    SalesCrm::Deals::Create.new(account: account, user: user)
                           .perform({ title: 'باقة 50 الف', amount: '50000', pipeline_id: pipeline.id, stage_id: qualified.id }.merge(attrs))
  end

  describe SalesCrm::Deals::Create do
    it 'sets currency, snapshot, position, source and logs created' do
      contact = create(:contact, account: account, name: 'أحمد')
      first = create_deal(contact_id: contact.id)
      second = create_deal(contact_id: contact.id)

      expect(first.amount_cents).to eq(5_000_000)
      expect(first.currency).to eq('SAR')
      expect(first.contact_name_snapshot).to eq('أحمد')
      expect(first.creator).to eq(user)
      expect(first.from_manual?).to be(true)
      expect([first.position, second.position]).to eq([1, 2])
      expect(first.activities.map(&:kind)).to eq(['created'])
    end

    it 'accepts Arabic-Indic digits and grouped amounts' do
      expect(create_deal(amount: '٥٠٬٠٠٠').amount_cents).to eq(5_000_000)
      expect(create_deal(amount: '1,250.50').amount_cents).to eq(125_050)
    end

    it 'marks a deal created from a conversation' do
      conversation = create(:conversation, account: account)
      deal = create_deal(conversation_id: conversation.display_id)
      expect(deal.conversation).to eq(conversation)
      expect(deal.from_conversation_source?).to be(true)
    end

    it 'rejects a stage from another pipeline' do
      other = create(:crm_pipeline, account: account)
      expect { create_deal(stage_id: other.stages.first.id) }.to raise_error(SalesCrm::ValidationError)
    end

    it 'broadcasts crm.deal_created' do
      expect { create_deal }.to have_enqueued_job(ActionCableBroadcastJob).with(anything, 'crm.deal_created', hash_including(:id))
    end
  end

  describe SalesCrm::Deals::Move do
    let(:move) { described_class.new(account: account, user: user) }

    it 'requires a reason when moving to the lost stage' do
      deal = create_deal
      expect { move.perform(deal, stage_id: lost.id) }.to raise_error(SalesCrm::ValidationError, /سبب|reason/i)
      expect(deal.reload.stage).to eq(qualified)
    end

    it 'moving to lost sets status, lost_at and the reason and logs lost' do
      deal = create_deal
      move.perform(deal, stage_id: lost.id, lost_reason: 'السعر مرتفع')
      deal.reload
      expect(deal).to be_lost
      expect(deal.lost_at).to be_present
      expect(deal.lost_reason).to eq('السعر مرتفع')
      expect(deal.activities.map(&:kind)).to include('stage_changed', 'lost')
    end

    it 'moving to won sets won_at and status' do
      deal = create_deal
      move.perform(deal, stage_id: won.id)
      expect(deal.reload).to be_won
      expect(deal.won_at).to be_present
    end

    it 'inserts at the requested position and shifts siblings' do
      a = create_deal(title: 'a')
      b = create_deal(title: 'b')
      c = create_deal(title: 'c')
      move.perform(c, stage_id: qualified.id, position: 1)
      expect([a, b, c].map { |d| d.reload.position }).to eq([2, 3, 1])
    end

    it 'raises StaleObjectError on an old lock_version' do
      deal = create_deal
      SalesCrm::Deals::Update.new(account: account, user: user).perform(deal, title: 'x')
      expect { move.perform(deal, stage_id: won.id, lock_version: 0) }.to raise_error(ActiveRecord::StaleObjectError)
    end
  end

  describe SalesCrm::Deals::Update do
    it 'logs amount and assignee changes only when they change' do
      deal = create_deal
      agent = create(:user, account: account)
      described_class.new(account: account, user: user).perform(deal, amount: '60000', assignee_id: agent.id, title: 'new')
      described_class.new(account: account, user: user).perform(deal, title: 'newer')
      expect(deal.reload.amount_cents).to eq(6_000_000)
      expect(deal.assignee).to eq(agent)
      expect(deal.activities.map(&:kind).sort).to eq(%w[amount_changed assignee_changed created])
    end
  end

  describe SalesCrm::Deals::Reopen do
    it 'returns a lost deal to the first open stage and clears the loss' do
      deal = create_deal
      SalesCrm::Deals::Move.new(account: account, user: user).perform(deal, stage_id: lost.id, lost_reason: 'x')
      described_class.new(account: account, user: user).perform(deal)
      deal.reload
      expect(deal).to be_open
      expect(deal.stage).to eq(pipeline.first_open_stage)
      expect(deal.lost_at).to be_nil
      expect(deal.lost_reason).to be_nil
      expect(deal.activities.first.kind).to eq('reopened')
    end

    it 'refuses to reopen an open deal' do
      expect { described_class.new(account: account, user: user).perform(create_deal) }.to raise_error(SalesCrm::ValidationError)
    end
  end

  describe 'discard and restore' do
    it 'soft deletes and restores' do
      deal = create_deal
      SalesCrm::Deals::Discard.new(account: account, user: user).perform(deal)
      expect(deal.reload).to be_discarded
      expect(account.crm_deals.kept).not_to include(deal)
      SalesCrm::Deals::Restore.new(account: account, user: user).perform(deal)
      expect(deal.reload).not_to be_discarded
      expect(deal.activities.map(&:kind)).to include('discarded', 'restored')
    end
  end

  describe SalesCrm::Deals::Search do
    it 'finds by normalized title or contact and counts per stage' do
      contact = create(:contact, account: account, name: 'أحمد العمري')
      create_deal(title: 'باقة ذهبية', contact_id: contact.id)
      create_deal(title: 'Other')
      SalesCrm::Deals::Move.new(account: account, user: user).perform(create_deal(title: 'z'), stage_id: won.id)

      result = described_class.new(account: account, user: user).perform(account.crm_deals.kept, pipeline: pipeline, q: 'احمد')
      expect(result[:deals].map(&:title)).to eq(['باقة ذهبية'])

      all = described_class.new(account: account, user: user).perform(account.crm_deals.kept, pipeline: pipeline)
      expect(all[:counts][qualified.id]).to eq(count: 2, total_cents: 10_000_000)
      expect(all[:counts][won.id][:count]).to eq(1)
      expect(all[:total]).to eq(3)
    end

    it 'board view caps each stage at 100 deals' do
      stub_const('SalesCrm::Deals::Search::BOARD_PER_STAGE', 2)
      3.times { |i| create_deal(title: "d#{i}") }
      result = described_class.new(account: account, user: user).perform(account.crm_deals.kept, pipeline: pipeline)
      expect(result[:deals].size).to eq(2)
      expect(result[:counts][qualified.id][:count]).to eq(3)
    end
  end

  describe SalesCrm::Forecast do
    it 'computes the expected value from stage probabilities' do
      create_deal
      lost_deal = create_deal(title: 'l', amount: '1000')
      SalesCrm::Deals::Move.new(account: account, user: user).perform(lost_deal, stage_id: lost.id, lost_reason: 'x')
      f = described_class.call(account.crm_deals.kept, pipeline: pipeline)
      expect(f.open_count).to eq(1)
      expect(f.open_total_cents).to eq(5_000_000)
      expect(f.expected_cents).to eq(1_250_000)
      expect(f.lost_count).to eq(1)
      expect(f.lost_total_cents).to eq(100_000)
      expect(f.currency).to eq('SAR')
    end
  end

  describe 'dense positions' do
    it 'renumbers the stage so index-based positions always stick' do
      move = SalesCrm::Deals::Move.new(account: account, user: user)
      a = create_deal(title: 'a')
      b = create_deal(title: 'b')
      c = create_deal(title: 'c')
      move.perform(a, stage_id: qualified.id, position: 3)
      expect([b, c, a].map { |d| d.reload.position }).to eq([1, 2, 3])
      move.perform(c, stage_id: qualified.id, position: 99)
      expect([b, a, c].map { |d| d.reload.position }).to eq([1, 2, 3])
    end

    it 'refuses to create a deal straight into the lost stage' do
      expect { create_deal(stage_id: lost.id) }.to raise_error(SalesCrm::ValidationError)
    end
  end
end
