# Custom (MyDesk)
require 'rails_helper'

# The follow-up, thank-you and "why not?" drafts, written when the employee asks (CONVERSATION_SALES_PLAN.md)
RSpec.describe SalesCrm::MessageDraft do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, contact: contact) }
  let(:deal) { create(:crm_deal, account: account, contact: contact, conversation: conversation, title: 'كراتين', amount_cents: 99_900) }
  let(:client) { instance_double(SmartAssistant::LlmClient) }

  before do
    allow(SmartAssistant::Config).to receive(:configured?).and_return(true)
    allow(SmartAssistant::LlmClient).to receive(:new).and_return(client)
    allow(client).to receive(:complete).and_return({ 'message' => ' هلا، هل اطلعت على العرض؟ ' })
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox, message_type: :incoming,
                     content: 'أرسلوا لي العرض')
  end

  def suggestion(kind)
    SalesCrm::Suggestion.create!(account: account, conversation: conversation, deal: deal, kind: kind)
  end

  def draft(kind) = described_class.new(account: account, suggestion: suggestion(kind)).perform

  it 'writes the follow-up from the conversation, counted as a Sales follow-up, and keeps it on the suggestion' do
    result = draft(:follow_up)

    expect(result).to eq('هلا، هل اطلعت على العرض؟')
    expect(SalesCrm::Suggestion.last.content).to eq('draft' => 'هلا، هل اطلعت على العرض؟')
    expect(SmartAssistant::LlmClient).to have_received(:new).with(account: account, kind: :crm_followup)
    expect(client).to have_received(:complete) do |instructions:, messages:, **|
      expect(messages.last[:content]).to include('أرسلوا لي العرض')
      expect(instructions).to include('كراتين')
      expect(instructions).not_to include('999')
    end
  end

  it 'counts the won and lost messages as Sales messages' do
    draft(:won_message)
    draft(:lost_question)
    expect(SmartAssistant::LlmClient).to have_received(:new).with(account: account, kind: :crm_message).twice
  end

  it 'explains when the assistant is not set up or the monthly limit is reached' do
    allow(SmartAssistant::Usage).to receive(:crm_limit_reached?).and_return(true)
    expect { draft(:follow_up) }.to raise_error(SalesCrm::ValidationError)
    expect(client).not_to have_received(:complete)
  end

  it 'says the assistant could not answer when the provider fails, and keeps no draft' do
    allow(client).to receive(:complete).and_raise(Faraday::ConnectionFailed, 'reset')
    item = suggestion(:follow_up)
    expect { described_class.new(account: account, suggestion: item).perform }
      .to raise_error(SalesCrm::ValidationError, I18n.t('sales_crm.errors.ai_unavailable'))
    expect(item.reload.content).not_to have_key('draft')
  end
end
