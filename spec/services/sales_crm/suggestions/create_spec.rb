# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SalesCrm::Suggestions::Create do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:deal) { create(:crm_deal, account: account, contact: contact, conversation: conversation) }

  it "makes a deal's suggestion about its conversation and customer, once while it is pending" do
    first = described_class.for_deal(deal, :follow_up)

    expect(first).to have_attributes(kind: 'follow_up', origin: 'schedule', conversation_id: conversation.id, contact_id: contact.id)
    expect(described_class.for_deal(deal, :follow_up)).to be_nil

    first.update!(status: :dismissed)
    expect(described_class.for_deal(deal, :follow_up)).to be_present
  end

  it "makes a conversation's suggestion with its content, once while it is pending" do
    made = described_class.for_conversation(conversation, :new_deal, origin: :automation, content: { 'title' => 'كراتين' })

    expect(made).to have_attributes(origin: 'automation', contact_id: contact.id, content: { 'title' => 'كراتين' })
    expect(described_class.for_conversation(conversation, :new_deal, origin: :assistant)).to be_nil
  end

  it 'leaves the surrounding transaction usable when another maker got there first' do
    described_class.record(account, kind: :new_deal, origin: :automation, conversation: conversation)

    ActiveRecord::Base.transaction do
      expect(described_class.record(account, kind: :new_deal, origin: :assistant, conversation: conversation)).to be_nil
      expect(account.crm_suggestions.count).to eq(1)
    end
  end
end
