# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SalesCrm::ActivityLog do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:deal) { create(:crm_deal, account: account) }

  it 'creates an activity row with kind, user and data' do
    activity = described_class.record(deal: deal, kind: 'stage_changed', user: user, data: { from_stage_id: 1, to_stage_id: 2 })
    expect(activity).to be_persisted
    expect(activity.account_id).to eq(account.id)
    expect(activity.kind).to eq('stage_changed')
    expect(activity.user).to eq(user)
    expect(activity.data).to eq('from_stage_id' => 1, 'to_stage_id' => 2)
  end

  it "moves the deal's last activity and last touch when a person acts, not when the system does" do
    deal.update_columns(last_activity_at: nil, last_touch_at: 2.days.ago) # rubocop:disable Rails/SkipsModelValidations
    described_class.record(deal: deal, kind: 'conversation_linked', user: nil)
    expect(deal.reload.last_touch_at).to be < 1.day.ago

    activity = described_class.record(deal: deal, kind: 'note_added', user: user)
    expect(deal.reload).to have_attributes(last_activity_at: activity.created_at, last_touch_at: activity.created_at)
  end

  it 'rejects an unknown kind' do
    expect { described_class.record(deal: deal, kind: 'bogus', user: nil) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'activities are read-only once written' do
    activity = described_class.record(deal: deal, kind: 'created', user: user)
    expect { activity.update!(kind: 'won') }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end
