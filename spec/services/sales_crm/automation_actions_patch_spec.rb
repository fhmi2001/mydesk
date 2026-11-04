# Custom (MyDesk)
require 'rails_helper'

# The Sales actions of automation rules (CONVERSATION_SALES_PLAN.md, idea ج1), run by Chatwoot's own action service
RSpec.describe SalesCrm::AutomationActionsPatch do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, name: 'سارة') }
  let(:conversation) { create(:conversation, account: account, contact: contact, assignee: agent) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:offer) { pipeline.stages.find { |stage| stage.name == 'تم إرسال العرض' } }

  before { account.enable_features!('sales_crm') }

  def run(action_name, params)
    rule = create(:automation_rule, account: account, actions: [{ action_name: action_name, action_params: [params] }])
    AutomationRules::ActionService.new(rule, account, conversation).perform
  end

  describe 'suggest_crm_deal' do
    it 'leaves a pending deal suggestion titled from the rule and the customer, never a deal' do
      run('suggest_crm_deal', { title: 'طلب جملة' })
      expect(SalesCrm::Suggestion.sole).to have_attributes(kind: 'new_deal', origin: 'automation', conversation_id: conversation.id,
                                                           content: { 'title' => 'طلب جملة — سارة' })
      expect(account.crm_deals.count).to eq(0)
    end
  end

  describe 'suggest_crm_deal on «تم تحديث المحادثة» when the priority becomes urgent' do
    before do
      create(:automation_rule, account: account, event_name: 'conversation_updated',
                               conditions: [{ attribute_key: 'priority', filter_operator: 'equal_to', values: ['urgent'],
                                              query_operator: nil }],
                               actions: [{ action_name: 'suggest_crm_deal', action_params: [{ title: 'عميل عاجل' }] }])
    end

    def update_conversation(attrs)
      conversation.update!(attrs)
      event = Events::Base.new('conversation.updated', Time.zone.now,
                               conversation: conversation, changed_attributes: conversation.previous_changes)
      AutomationRuleListener.instance.conversation_updated(event)
    end

    it 'suggests a deal once the conversation is urgent' do
      update_conversation(priority: :urgent)
      expect(SalesCrm::Suggestion.sole).to have_attributes(kind: 'new_deal', content: { 'title' => 'عميل عاجل — سارة' })
    end

    it 'does not suggest again for the same conversation on later updates, even after a dismiss' do
      update_conversation(priority: :urgent)
      SalesCrm::Suggestion.sole.decide!(:dismissed, agent)
      update_conversation(status: :pending)
      expect(SalesCrm::Suggestion.count).to eq(1)
    end

    it 'does not suggest a deal for a conversation that already has one followed in it' do
      create(:crm_deal, account: account, pipeline: pipeline, contact: contact, conversation: conversation)
      update_conversation(priority: :urgent)
      expect(SalesCrm::Suggestion.count).to eq(0)
    end
  end

  describe 'create_crm_task' do
    it "gives the conversation's assignee a task on the conversation, due after the hours" do
      freeze_time do
        run('create_crm_task', { title: 'اتصل بالعميل', kind: 'call', hours: 4 })
        expect(account.crm_tasks.sole).to have_attributes(title: 'اتصل بالعميل', kind: 'call', due_at: 4.hours.from_now,
                                                          assignee_id: agent.id, conversation_id: conversation.id,
                                                          contact_id: contact.id, origin: 'automation', creator_id: nil)
      end
    end

    it 'goes to an administrator when nobody handles the conversation, and onto the deal followed there' do
      admin = create(:user, account: account, role: :administrator)
      conversation.update!(assignee: nil)
      deal = create(:crm_deal, account: account, pipeline: pipeline, contact: contact, conversation: conversation)
      run('create_crm_task', { title: 'x', kind: 'task', hours: 1 })
      expect(account.crm_tasks.sole).to have_attributes(assignee_id: admin.id, deal_id: deal.id)
    end

    it "reaches the assignee's task board live, like a task an employee adds" do
      expect { run('create_crm_task', { title: 'x', kind: 'task', hours: 1 }) }
        .to have_enqueued_job(ActionCableBroadcastJob).with(anything, 'crm.task_created', hash_including(assignee_id: agent.id))
    end
  end

  describe 'move_crm_deal' do
    let!(:deal) do
      create(:crm_deal, account: account, pipeline: pipeline, contact: contact, conversation: conversation, assignee: agent)
    end

    it 'moves the deal followed in the conversation, as the system, so its last activity stays' do
      deal.update_columns(last_activity_at: nil) # rubocop:disable Rails/SkipsModelValidations
      run('move_crm_deal', { stage_id: offer.id })
      expect(deal.reload).to have_attributes(stage_id: offer.id, last_activity_at: nil)
      expect(deal.activities.first).to have_attributes(kind: 'stage_changed', user_id: nil)
    end

    it 'never moves a deal to the lost stage, which needs a reason' do
      run('move_crm_deal', { stage_id: pipeline.lost_stage.id })
      expect(deal.reload.stage_id).not_to eq(pipeline.lost_stage.id)
    end
  end

  it 'does nothing for an account without the Sales section' do
    account.disable_features!('sales_crm')
    run('suggest_crm_deal', { title: 'x' })
    run('create_crm_task', { title: 'x', kind: 'task', hours: 1 })
    expect(SalesCrm::Suggestion.count + account.crm_tasks.count).to eq(0)
  end
end
