# Custom (MyDesk)
require 'rails_helper'

# The follow-up when a customer goes quiet (CONVERSATION_SALES_PLAN.md): a task and an empty suggestion, never
# a message to the customer
RSpec.describe SalesCrm::FollowUpJob do
  let(:account) { create(:account, locale: 'ar') }
  let(:owner) { create(:user, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:offer) { pipeline.stages.find { |stage| stage.name == 'تم إرسال العرض' } }
  let!(:deal) do
    create(:crm_deal, account: account, pipeline: pipeline, stage: offer, contact: contact, assignee: owner, conversation: conversation,
                      title: 'كراتين')
  end

  before do
    account.enable_features!('sales_crm')
    offer.update!(silence_followup: true)
    deal.update_columns(last_message_at: 4.days.ago) # rubocop:disable Rails/SkipsModelValidations
  end

  def customer_writes(at, in_conversation: conversation)
    create(:message, account: account, conversation: in_conversation, inbox: in_conversation.inbox, message_type: :incoming,
                     sender: contact, created_at: at)
  end

  it "gives the owner a follow-up task and leaves an empty follow-up suggestion in the deal's conversation" do
    described_class.perform_now

    task = deal.tasks.from_follow_up.sole
    expect(task).to have_attributes(title: 'متابعة: كراتين', assignee_id: owner.id, conversation_id: conversation.id, status: 'open')
    suggestion = SalesCrm::Suggestion.sole
    expect(suggestion).to have_attributes(kind: 'follow_up', deal_id: deal.id, conversation_id: conversation.id, origin: 'schedule',
                                          status: 'pending', content: {})
  end

  it 'does it once, even after the task is done, until the employee writes again' do
    described_class.perform_now
    deal.tasks.update_all(status: :done) # rubocop:disable Rails/SkipsModelValidations
    described_class.perform_now
    expect(deal.tasks.from_follow_up.count).to eq(1)
  end

  it 'leaves a customer who replied, in any of their conversations' do
    customer_writes(1.day.ago, in_conversation: create(:conversation, account: account, contact: contact))
    described_class.perform_now
    expect(deal.tasks.count).to eq(0)
  end

  it 'waits for the silent days of the account' do
    account.update!(crm_followup_days: 5)
    described_class.perform_now
    expect(deal.tasks.count).to eq(0)
  end

  it 'leaves deals without a conversation, without a reply yet, or in a stage that has it off' do
    deal.update_columns(active_conversation_id: nil) # rubocop:disable Rails/SkipsModelValidations
    described_class.perform_now
    deal.update_columns(active_conversation_id: conversation.id, last_message_at: nil) # rubocop:disable Rails/SkipsModelValidations
    described_class.perform_now
    deal.update_columns(last_message_at: 4.days.ago) # rubocop:disable Rails/SkipsModelValidations
    offer.update!(silence_followup: false)
    described_class.perform_now
    expect(deal.tasks.count).to eq(0)
  end

  it 'leaves an account without the Sales section' do
    account.disable_features!('sales_crm')
    described_class.perform_now
    expect(deal.tasks.count).to eq(0)
  end
end
