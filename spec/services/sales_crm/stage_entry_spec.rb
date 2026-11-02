# Custom (MyDesk)
require 'rails_helper'

# What a deal entering a stage sets off (CONVERSATION_SALES_PLAN.md, phase 3)
RSpec.describe SalesCrm::StageEntry do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:lead) { pipeline.stages.find { |stage| stage.name == 'عميل محتمل' } }
  let(:offer) { pipeline.stages.find { |stage| stage.name == 'تم إرسال العرض' } }
  let(:conversation) { create(:conversation, account: account) }

  before { offer.update!(followup_task_days: 2, followup_task_title: 'متابعة العرض') }

  def create_deal(stage)
    SalesCrm::Deals::Create.new(account: account, user: owner)
                           .perform(title: 'كراتين', amount: '100', close_date: Date.current + 30, pipeline_id: pipeline.id,
                                    stage_id: stage.id, conversation_id: conversation.display_id)
  end

  def move(deal, stage)
    SalesCrm::Deals::Move.new(account: account, user: owner).perform(deal, stage_id: stage.id)
  end

  it "opens the stage's task for the deal's owner, due after its days" do
    deal = create_deal(lead)
    freeze_time do
      move(deal, offer)
      task = deal.tasks.from_stage_rule.sole
      expect(task).to have_attributes(title: 'متابعة العرض', assignee_id: owner.id, due_at: 2.days.from_now, status: 'open',
                                      conversation_id: conversation.id, creator_id: nil)
    end
  end

  it 'opens it when a deal is created in the stage too' do
    expect(create_deal(offer).tasks.from_stage_rule.count).to eq(1)
  end

  it 'never opens a second one while the first is open' do
    deal = create_deal(offer)
    move(deal, lead)
    move(deal, offer)
    expect(deal.tasks.from_stage_rule.count).to eq(1)
  end

  describe 'won and lost messages (idea ج2)' do
    before { account.enable_features!('sales_crm') }

    it 'suggests a thank-you in the conversation when the deal is won' do
      deal = create_deal(lead)
      move(deal, pipeline.won_stage)
      expect(SalesCrm::Suggestion.sole).to have_attributes(kind: 'won_message', deal_id: deal.id, conversation_id: conversation.id,
                                                           status: 'pending', content: {})
    end

    it 'suggests asking why when the deal is lost' do
      deal = create_deal(lead)
      SalesCrm::Deals::Move.new(account: account, user: owner).perform(deal, stage_id: pipeline.lost_stage.id, lost_reason: 'السعر')
      expect(SalesCrm::Suggestion.sole).to have_attributes(kind: 'lost_question', deal_id: deal.id)
    end

    it 'suggests nothing when the manager turned them off, or for a deal without a conversation' do
      account.update!(crm_won_lost_messages: false)
      move(create_deal(lead), pipeline.won_stage)
      account.update!(crm_won_lost_messages: true)
      deal = create_deal(lead)
      deal.update_columns(active_conversation_id: nil) # rubocop:disable Rails/SkipsModelValidations
      move(deal, pipeline.won_stage)
      expect(SalesCrm::Suggestion.count).to eq(0)
    end
  end

  it 'opens nothing for a stage without a rule, or when the deal stays in the same stage' do
    deal = create_deal(lead)
    expect(deal.tasks.count).to eq(0)
    move(deal, offer)
    deal.tasks.update_all(status: :done) # rubocop:disable Rails/SkipsModelValidations
    move(deal, offer)
    expect(deal.tasks.from_stage_rule.count).to eq(1)
  end
end
