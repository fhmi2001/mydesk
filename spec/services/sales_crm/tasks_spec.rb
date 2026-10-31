# Custom (MyDesk): task services
require 'rails_helper'

RSpec.describe SalesCrm::Tasks do
  let(:account) { create(:account, settings: { 'reporting_timezone' => 'Asia/Riyadh' }) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:scope) { account.crm_tasks }

  def list(user, kind, now: Time.current)
    SalesCrm::Tasks::List.new(account: account, user: user).perform(scope, kind: kind, now: now)
  end

  describe SalesCrm::Tasks::List do
    it 'today uses the account time zone' do
      # 23:30 Riyadh on Oct 31 = 20:30 UTC; a task at 00:30 Riyadh Nov 1 is "tomorrow", one at 23:45 Riyadh is "today"
      now = Time.utc(2026, 10, 31, 20, 30)
      today_task = create(:crm_task, account: account, assignee: agent, due_at: Time.utc(2026, 10, 31, 20, 45))
      tomorrow_task = create(:crm_task, account: account, assignee: agent, due_at: Time.utc(2026, 10, 31, 21, 30))
      expect(list(agent, 'today', now: now)).to eq([today_task])
      expect(list(agent, 'upcoming', now: now)).to eq([tomorrow_task])
    end

    it 'overdue excludes done and future tasks' do
      now = Time.current
      overdue = create(:crm_task, account: account, assignee: agent, due_at: now - 1.hour)
      create(:crm_task, account: account, assignee: agent, due_at: now - 1.hour, status: :done, done_at: now)
      create(:crm_task, account: account, assignee: agent, due_at: now + 1.hour)
      expect(list(agent, 'overdue', now: now)).to eq([overdue])
    end

    it 'an agent asking for all gets mine; an admin gets all open tasks' do
      mine = create(:crm_task, account: account, assignee: agent)
      theirs = create(:crm_task, account: account, assignee: admin)
      expect(list(agent, 'all')).to eq([mine])
      expect(list(admin, 'all')).to contain_exactly(mine, theirs)
    end

    it 'counts overdue tasks of the user only' do
      now = Time.current
      create(:crm_task, account: account, assignee: agent, due_at: now - 1.minute)
      create(:crm_task, account: account, assignee: admin, due_at: now - 1.minute)
      expect(described_class.new(account: account, user: agent).overdue_count(scope, now: now)).to eq(1)
    end
  end

  describe SalesCrm::Tasks::Create do
    it 'defaults the assignee to the actor, inherits the deal contact and logs task_added' do
      contact = create(:contact, account: account)
      deal = create(:crm_deal, account: account, contact: contact, assignee: agent)
      task = described_class.new(account: account, user: agent).perform(title: 'اتصل', deal_id: deal.id, due_at: 1.day.from_now)
      expect(task.assignee).to eq(agent)
      expect(task.creator).to eq(agent)
      expect(task.contact).to eq(contact)
      expect(deal.activities.first.kind).to eq('task_added')
    end
  end

  describe SalesCrm::Tasks::Complete do
    it 'sets done and logs task_done; completing twice is harmless' do
      deal = create(:crm_deal, account: account)
      task = create(:crm_task, account: account, deal: deal, assignee: agent)
      described_class.new(account: account, user: agent).perform(task)
      described_class.new(account: account, user: agent).perform(task)
      expect(task.reload).to be_done
      expect(task.done_at).to be_present
      expect(deal.activities.where(kind: 'task_done').count).to eq(1)
    end
  end

  describe SalesCrm::Tasks::Update do
    it 're-arms the reminder when the due date moves later' do
      task = create(:crm_task, account: account, assignee: agent, due_at: 1.hour.ago, reminded_at: 30.minutes.ago)
      described_class.new(account: account, user: agent).perform(task, due_at: 2.hours.from_now)
      expect(task.reload.reminded_at).to be_nil
    end
  end

  describe 'a record history' do
    it 'lists every task of a deal, open then done, for an agent too' do
      deal = create(:crm_deal, account: account)
      theirs = create(:crm_task, account: account, deal: deal, assignee: admin)
      done = create(:crm_task, account: account, deal: deal, assignee: agent, status: :done, done_at: Time.current)
      mine = create(:crm_task, account: account, deal: deal, assignee: agent)
      list = SalesCrm::Tasks::List.new(account: account, user: agent).perform(scope, kind: 'all', deal_id: deal.id)
      expect(list.map(&:id)).to eq([theirs.id, mine.id, done.id].sort_by { |id| [id == done.id ? 1 : 0, -id] })
      expect(list.map(&:status)).to eq(%w[open open done])
    end
  end
end
