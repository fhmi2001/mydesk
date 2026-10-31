# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SalesCrm::Broadcast do
  let(:account) { create(:account) }

  before { create(:user, account: account) }

  it 'enqueues an ActionCable broadcast to the account users with the event name and payload' do
    expect do
      described_class.call(account, 'crm.deal_moved', { id: 5, stage_id: 2 })
    end.to have_enqueued_job(ActionCableBroadcastJob).with(
      a_collection_including(*account.users.map(&:pubsub_token)),
      'crm.deal_moved',
      hash_including(id: 5, stage_id: 2, account_id: account.id)
    )
  end
end
