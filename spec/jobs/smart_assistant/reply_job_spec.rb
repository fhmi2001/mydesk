require 'rails_helper'

RSpec.describe SmartAssistant::ReplyJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:assistant) do
    SmartAssistant.for_account(account).tap do |record|
      record.update!(enabled: true, inbox_ids: [inbox.id], handoff_message: 'A colleague will join you')
      record.sync_inbox_links!
    end
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, content: 'كم مدة التوصيل؟') }
  let(:responder) { instance_double(SmartAssistant::Responder) }
  let(:result) { { reply: 'يصل الطلب خلال يومين', handoff: false, sources: [] } }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return({ agent.id.to_s => 'online' })
    allow(SmartAssistant::Responder).to receive(:new).and_return(responder)
    allow(responder).to receive(:perform).and_return(result)
  end

  it 'starts the conversation pending and replies as the assistant bot' do
    expect(conversation).to be_pending

    described_class.perform_now(message.id)

    reply = conversation.messages.outgoing.last
    expect(reply).to have_attributes(content: 'يصل الطلب خلال يومين', sender: assistant.agent_bot)
    expect(conversation.reload).to have_attributes(status: 'pending', assignee_id: nil)
    expect(SmartAssistant::Responder).to have_received(:new)
      .with(assistant: assistant, messages: [{ role: :user, content: 'كم مدة التوصيل؟' }])
  end

  it 'replies, then assigns the conversation to an agent when it hands over' do
    result[:handoff] = true

    described_class.perform_now(message.id)

    expect(conversation.messages.outgoing.last.content).to eq('يصل الطلب خلال يومين')
    expect(conversation.reload).to have_attributes(status: 'open', assignee_id: agent.id)
  end

  it 'leaves an earlier message to the job of the latest one' do
    message
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, content: 'وكم السعر؟')

    described_class.perform_now(message.id)

    expect(responder).not_to have_received(:perform)
  end

  it 'drops a reply when the customer wrote again while it was being written' do
    allow(responder).to receive(:perform) do
      create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, content: 'وكم السعر؟')
      result
    end

    described_class.perform_now(message.id)

    expect(conversation.messages.outgoing).to be_empty
  end

  it 'does not answer a conversation an agent has taken' do
    conversation.update!(assignee: agent)

    described_class.perform_now(message.id)

    expect(responder).not_to have_received(:perform)
  end

  it 'assigns attachments without text to an agent' do
    message.update!(content: nil)

    described_class.perform_now(message.id)

    expect(responder).not_to have_received(:perform)
    expect(conversation.reload).to have_attributes(status: 'open', assignee_id: agent.id)
  end

  it 'hands over with the handoff message after the reply limit' do
    assistant.update!(max_replies: 1)
    create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :outgoing, sender: assistant.agent_bot)

    described_class.perform_now(message.id)

    expect(conversation.messages.outgoing.last.content).to eq('A colleague will join you')
    expect(conversation.reload).to have_attributes(status: 'open', assignee_id: agent.id)
  end

  it 'tries again when the reply fails, and hands over only after the last try' do
    allow(responder).to receive(:perform).and_raise(Faraday::SSLError, 'unexpected eof')
    message
    clear_enqueued_jobs

    described_class.perform_now(message.id)
    expect(conversation.reload).to be_pending
    expect(described_class).to have_been_enqueued.with(message.id)

    # Each run performs the retry queued by the one before
    (described_class::ATTEMPTS - 1).times { perform_enqueued_jobs(only: described_class) }
    expect(responder).to have_received(:perform).exactly(described_class::ATTEMPTS).times
    expect(conversation.reload).to have_attributes(status: 'open', assignee_id: agent.id)
  end

  it 'does nothing once the assistant is turned off' do
    assistant.update!(enabled: false)

    described_class.perform_now(message.id)

    expect(responder).not_to have_received(:perform)
  end
end
