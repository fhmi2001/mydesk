# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SalesCrm::Broadcast do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:owner) { create(:user, account: account, role: :agent) }
  let!(:colleague) { create(:user, account: account, role: :agent) }

  it 'enqueues an ActionCable broadcast to the administrators and the given users, with the event name and payload' do
    expect do
      described_class.call(account, 'crm.deal_moved', { id: 5, stage_id: 2 }, to: owner.id)
    end.to have_enqueued_job(ActionCableBroadcastJob).with(
      contain_exactly(admin.pubsub_token, owner.pubsub_token),
      'crm.deal_moved',
      hash_including(id: 5, stage_id: 2, account_id: account.id)
    )
    expect(colleague.pubsub_token).to be_present
  end
end
