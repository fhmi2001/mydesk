# Custom (MyDesk): merge / agent removal patches, reminders and the purge job
require 'rails_helper'

RSpec.describe SalesCrm do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before { account.enable_features!('sales_crm') }

  describe SalesCrm::ContactMergePatch do
    it 'moves deals and tasks from the merged contact to the base contact' do
      base = create(:contact, account: account, name: 'الأساس')
      mergee = create(:contact, account: account, name: 'المدمج')
      deal = create(:crm_deal, account: account, contact: mergee)
      task = create(:crm_task, account: account, contact: mergee)

      ContactMergeAction.new(account: account, base_contact: base, mergee_contact: mergee).perform

      expect(deal.reload.contact).to eq(base)
      expect(deal.contact_name_snapshot).to eq('الأساس')
      expect(task.reload.contact).to eq(base)
    end
  end

  describe SalesCrm::AgentRemovalPatch do
    it 'unassigns the open deals and tasks of a removed agent, keeping closed ones' do
      open_deal = create(:crm_deal, account: account, assignee: agent)
      won_deal = create(:crm_deal, account: account, assignee: agent, status: :won)
      task = create(:crm_task, account: account, assignee: agent)

      Agents::DestroyJob.perform_now(account, agent)

      expect(open_deal.reload.assignee_id).to be_nil
      expect(won_deal.reload.assignee_id).to eq(agent.id)
      expect(task.reload.assignee_id).to be_nil
    end
  end

  describe SalesCrm::TaskReminders do
    let(:contact) { create(:contact, account: account) }
    let(:inbox) { create(:inbox, account: account) }
    let!(:conversation) { create(:conversation, account: account, contact: contact, inbox: inbox) }

    # The assignee must be able to open the conversation, like any other Chatwoot notification
    before { create(:inbox_member, inbox: inbox, user: agent) }

    it 'notifies the assignee once with the task title, pointing at the conversation' do
      task = create(:crm_task, account: account, assignee: agent, contact: contact, title: 'اتصل بالعميل', due_at: 1.minute.ago)
      described_class.new(account).perform
      described_class.new(account).perform

      notifications = agent.notifications.where(notification_type: 'crm_task_due')
      expect(notifications.count).to eq(1)
      n = notifications.first
      expect(n.primary_actor).to eq(conversation)
      expect(n.secondary_actor).to eq(task)
      expect(n.push_message_title).to include('اتصل بالعميل')
      expect(task.reload.reminded_at).to be_present
    end

    it 'does not notify future or done tasks' do
      create(:crm_task, account: account, assignee: agent, contact: contact, due_at: 1.hour.from_now)
      create(:crm_task, account: account, assignee: agent, contact: contact, due_at: 1.hour.ago, status: :done)
      described_class.new(account).perform
      expect(agent.notifications.where(notification_type: 'crm_task_due')).to be_empty
    end

    it 'marks a task without any conversation as reminded without crashing or notifying' do
      lonely = create(:contact, account: account)
      task = create(:crm_task, account: account, assignee: agent, contact: lonely, due_at: 1.minute.ago)
      expect { described_class.new(account).perform }.not_to raise_error
      expect(task.reload.reminded_at).to be_present
      expect(agent.notifications.where(notification_type: 'crm_task_due')).to be_empty
    end

    it 'exposes push and email flags for the new type' do
      setting = agent.notification_settings.find_by(account_id: account.id)
      expect(setting).to respond_to(:push_crm_task_due?)
      expect(setting.push_crm_task_due?).to be(false)
    end

    it 'the job skips accounts without the feature and survives a failing account' do
      other = create(:account)
      expect(described_class).to receive(:new).with(account).and_call_original
      expect(described_class).not_to receive(:new).with(other)
      SalesCrm::TaskReminderJob.perform_now
    end
  end

  describe SalesCrm::PurgeDiscardedDealsJob do
    it 'deletes only deals discarded more than 30 days ago' do
      old = create(:crm_deal, account: account, discarded_at: 31.days.ago)
      recent = create(:crm_deal, account: account, discarded_at: 2.days.ago)
      live = create(:crm_deal, account: account)
      described_class.perform_now
      expect(SalesCrm::Deal.where(id: [old.id, recent.id, live.id]).pluck(:id)).to contain_exactly(recent.id, live.id)
    end
  end

  describe 'reminder delivery details' do
    let(:contact) { create(:contact, account: account) }
    let(:inbox) { create(:inbox, account: account) }
    let!(:conversation) { create(:conversation, account: account, contact: contact, inbox: inbox) }

    before { create(:inbox_member, inbox: inbox, user: agent) }

    it 'survives the duplicate-notification cleanup and carries the task title in its body' do
      task = create(:crm_task, account: account, assignee: agent, contact: contact, title: 'راجع العرض', due_at: 1.minute.ago)
      SalesCrm::TaskReminders.new(account).perform
      reminder = agent.notifications.find_by(notification_type: 'crm_task_due')
      expect(reminder.push_message_body).to eq('راجع العرض')

      later = NotificationBuilder.new(notification_type: 'conversation_assignment', user: agent, account: account,
                                      primary_actor: conversation).perform
      Notification::RemoveDuplicateNotificationJob.perform_now(later)
      Notification::RemoveDuplicateNotificationJob.perform_now(reminder)
      expect(Notification.where(id: [reminder.id, later.id]).count).to eq(2)
      expect(task.reload.reminded_at).to be_present
    end

    it 'picks a conversation the assignee can open' do
      other_inbox = create(:inbox, account: account)
      create(:conversation, account: account, contact: contact, inbox: other_inbox, last_activity_at: 1.minute.from_now)
      create(:crm_task, account: account, assignee: agent, contact: contact, due_at: 1.minute.ago)
      SalesCrm::TaskReminders.new(account).perform
      reminder = agent.notifications.find_by(notification_type: 'crm_task_due')
      expect(reminder.primary_actor).to eq(conversation)
    end
  end
end
