require 'rails_helper'

RSpec.describe SmartAssistant do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:assistant) { described_class.for_account(account).tap { |record| record.update!(inbox_ids: [inbox.id]) } }

  it 'creates and names its agent bot' do
    expect(assistant.agent_bot).to have_attributes(account_id: account.id, name: assistant.name, outgoing_url: nil)

    assistant.update!(name: 'Noura')
    expect(assistant.agent_bot.reload.name).to eq('Noura')
  end

  it 'links its bot to the chosen inboxes only while enabled' do
    assistant.update!(enabled: true)
    assistant.sync_inbox_links!
    expect(inbox.reload.agent_bot).to eq(assistant.agent_bot)

    assistant.update!(enabled: false)
    assistant.sync_inbox_links!
    expect(AgentBotInbox.where(inbox: inbox)).to be_empty
  end

  it 'refuses an inbox that another bot answers' do
    create(:agent_bot_inbox, inbox: inbox, agent_bot: create(:agent_bot, account: account))
    assistant.update!(enabled: true)

    expect { assistant.sync_inbox_links! }.to raise_error(ActiveRecord::RecordInvalid)
    expect(assistant.errors[:inbox_ids].first).to include(inbox.name)
  end

  it 'rejects inboxes of another account' do
    other_inbox = create(:inbox)

    expect(described_class.for_account(account).update(inbox_ids: [other_inbox.id])).to be(false)
  end
end
