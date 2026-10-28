require 'rails_helper'

RSpec.describe SmartAssistantListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming) }
  let(:enable_assistant) do
    SmartAssistant.for_account(account).tap { |assistant| assistant.update!(enabled: true, inbox_ids: [inbox.id]) }.sync_inbox_links!
  end

  describe '#message_created' do
    let(:event) { Events::Base.new('message.created', Time.zone.now, message: message) }

    it 'queues a reply right away for a customer message in an inbox the assistant answers' do
      enable_assistant

      expect { listener.message_created(event) }.to have_enqueued_job(SmartAssistant::ReplyJob).with(message.id).at(:no_wait)
    end

    it 'ignores inboxes without the assistant' do
      expect { listener.message_created(event) }.not_to have_enqueued_job(SmartAssistant::ReplyJob)
    end
  end

  describe '#assignee_changed' do
    let(:event) { Events::Base.new('assignee.changed', Time.zone.now, conversation: conversation) }

    before { enable_assistant }

    it 'gives the conversation to the agent who assigned it to themselves' do
      conversation.update!(assignee: agent)

      listener.assignee_changed(event)

      expect(conversation.reload).to have_attributes(status: 'open', assignee_id: agent.id)
    end

    it 'keeps the assistant when nobody is assigned' do
      listener.assignee_changed(event)

      expect(conversation.reload).to be_pending
    end
  end
end
