# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SalesCrm::Task do
  let(:account) { create(:account) }

  it 'is overdue only when open and past due' do
    now = Time.zone.parse('2026-10-31 12:00')
    expect(build(:crm_task, account: account, due_at: now - 1.hour).overdue?(now)).to be(true)
    expect(build(:crm_task, account: account, due_at: now - 1.hour, status: :done).overdue?(now)).to be(false)
    expect(build(:crm_task, account: account, due_at: nil).overdue?(now)).to be(false)
  end

  it 'due scope returns open, past-due, unreminded tasks only' do
    now = Time.current
    due = create(:crm_task, account: account, due_at: now - 1.minute)
    create(:crm_task, account: account, due_at: now - 1.minute, reminded_at: now)
    create(:crm_task, account: account, due_at: now + 1.hour)
    create(:crm_task, account: account, due_at: now - 1.minute, status: :done)
    expect(described_class.due(now)).to eq([due])
  end

  it 'survives deletion of its deal' do
    deal = create(:crm_deal, account: account)
    task = create(:crm_task, account: account, deal: deal)
    deal.destroy!
    expect(task.reload.deal_id).to be_nil
  end
end
