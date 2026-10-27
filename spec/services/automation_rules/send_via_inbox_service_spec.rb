require 'rails_helper'

RSpec.describe AutomationRules::SendViaInboxService do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, phone_number: '+966500000001', email: 'customer@example.com') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:rule) { create(:automation_rule, account: account) }
  let(:sms_inbox) do
    create(:inbox, account: account, channel: create(:channel_sms, account: account, phone_number: '+966511111111'))
  end

  def perform(inbox, message = 'مرحبا {{contact.name}}')
    described_class.new(rule: rule, conversation: conversation, inbox: inbox, message: message).perform
  end

  it 'sends through the chosen inbox in a resolved conversation, with variables filled in' do
    perform(sms_inbox)

    sent = sms_inbox.messages.last
    expect(sent).to have_attributes(message_type: 'outgoing', content: "مرحبا #{contact.name}")
    expect(sent.content_attributes['automation_rule_id']).to eq(rule.id)
    expect(sent.conversation).to have_attributes(contact_id: contact.id, status: 'resolved')
    expect(sent.conversation.contact_inbox.source_id).to eq('+966500000001')
  end

  it 'reuses the open conversation the contact already has in that inbox' do
    contact_inbox = create(:contact_inbox, contact: contact, inbox: sms_inbox, source_id: '+966500000001')
    open_conversation = create(:conversation, account: account, inbox: sms_inbox, contact: contact,
                                              contact_inbox: contact_inbox, status: :open)

    expect { perform(sms_inbox) }.not_to(change { sms_inbox.conversations.count })
    expect(open_conversation.messages.outgoing.count).to eq(1)
  end

  it 'reuses the WhatsApp Web address instead of starting a new thread each time' do
    allow(WhatsappWeb::Config).to receive(:api_url).and_return('http://gateway.test')
    channel = Channel::Api.create!(account: account, webhook_url: 'http://gateway.test/chatwoot/webhook/mydesk-1-aaaa')
    whatsapp_inbox = create(:inbox, account: account, channel: channel)

    2.times { perform(whatsapp_inbox) }

    expect(whatsapp_inbox.contact_inboxes.where(contact: contact).count).to eq(1)
    expect(whatsapp_inbox.messages.outgoing.count).to eq(2)
  end

  it 'sends in the same conversation when the chosen inbox is the conversation\'s own' do
    contact_inbox = create(:contact_inbox, contact: contact, inbox: sms_inbox, source_id: '+966500000001')
    own = create(:conversation, account: account, inbox: sms_inbox, contact: contact, contact_inbox: contact_inbox,
                                status: :resolved)

    described_class.new(rule: rule, conversation: own, inbox: sms_inbox, message: 'شكراً').perform

    expect(own.messages.outgoing.count).to eq(1)
    expect(sms_inbox.conversations.count).to eq(1)
  end

  it 'skips channels that cannot start a conversation, and contacts without a number' do
    perform(create(:inbox, account: account)) # web widget
    contact.update!(phone_number: nil)
    perform(sms_inbox)

    expect(Message.outgoing.where(account: account)).to be_empty
  end

  it 'runs from an automation rule action' do
    rule.update!(actions: [{ action_name: 'send_message_via_inbox', action_params: [{ inbox_id: sms_inbox.id, message: 'شكراً' }] }])

    AutomationRules::ActionService.new(rule, account, conversation).perform

    expect(sms_inbox.messages.last&.content).to eq('شكراً')
  end
end
