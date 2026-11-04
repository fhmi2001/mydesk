# Custom (MyDesk)
require 'rails_helper'

# An employee's reply in a deal's conversation (docs/mydesk/CONVERSATION_SALES_PLAN.md)
RSpec.describe SalesCrm::MessageListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let!(:deal) { create(:crm_deal, account: account, contact: contact, assignee: owner, conversation: conversation) }

  before do
    account.enable_features!('sales_crm')
    deal.update_columns(last_activity_at: nil, last_message_at: nil, last_touch_at: 5.days.ago) # rubocop:disable Rails/SkipsModelValidations
  end

  it 'listens to the async dispatcher' do
    message = create(:message, account: account, conversation: conversation, inbox: conversation.inbox, message_type: :outgoing,
                               sender: owner)
    Rails.configuration.dispatcher.async_dispatcher.publish_event('message.created', Time.zone.now, message: message)
    expect(deal.reload.last_message_at).to eq(message.reload.created_at)
  end

  def reply(conversation, sender: owner, **attrs)
    message = create(:message, account: account, conversation: conversation, inbox: conversation.inbox, message_type: :outgoing,
                               sender: sender, **attrs)
    listener.message_created(Events::Base.new('message.created', Time.zone.now, message: message))
    message.reload
  end

  it 'moves the last message and last touch of the deal followed in this conversation, never its last activity' do
    message = reply(conversation)
    expect(deal.reload).to have_attributes(last_message_at: message.created_at, last_touch_at: message.created_at,
                                           last_activity_at: nil)
  end

  it "leaves the customer's other deals alone" do
    other = create(:crm_deal, account: account, contact: contact, assignee: owner,
                              conversation: create(:conversation, account: account, contact: contact))
    other.update_columns(last_message_at: nil) # rubocop:disable Rails/SkipsModelValidations
    reply(conversation)
    expect(other.reload.last_message_at).to be_nil
  end

  it 'ignores private notes, bot and automation messages, and incoming messages' do
    bot = create(:agent_bot, account: account)
    reply(conversation, private: true)
    reply(conversation, sender: bot)
    reply(conversation, content_attributes: { automation_rule_id: 1 })
    reply(conversation, sender: contact, message_type: :incoming)
    expect(deal.reload.last_message_at).to be_nil
  end

  it 'updates at most once a minute' do
    first = reply(conversation)
    travel 30.seconds do
      reply(conversation)
      expect(deal.reload.last_message_at).to eq(first.created_at)
    end
  end

  it 'does nothing when the Sales section is off' do
    account.disable_features!('sales_crm')
    reply(conversation)
    expect(deal.reload.last_message_at).to be_nil
  end

  describe 'a new conversation of the same customer' do
    let(:new_conversation) { create(:conversation, account: account, contact: contact) }

    it "becomes the deal's active conversation when its owner replies there and the customer has one open deal" do
      reply(new_conversation)
      deal.reload
      expect(deal).to have_attributes(active_conversation_id: new_conversation.id, conversation_id: conversation.id)
      expect(deal.last_message_at).to be_present
      expect(deal.activities.first).to have_attributes(kind: 'conversation_linked', user_id: nil)
      expect(deal.activities.first.data).to include('display_id' => new_conversation.display_id)
    end

    it 'stays unlinked when someone other than the owner replies' do
      reply(new_conversation, sender: create(:user, account: account, role: :agent))
      expect(deal.reload.active_conversation_id).to eq(conversation.id)
    end

    it 'stays unlinked when the customer has more than one open deal' do
      create(:crm_deal, account: account, contact: contact, assignee: owner)
      reply(new_conversation)
      expect(deal.reload.active_conversation_id).to eq(conversation.id)
    end
  end
end
