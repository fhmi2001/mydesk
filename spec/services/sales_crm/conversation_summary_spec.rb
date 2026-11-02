# Custom (MyDesk)
require 'rails_helper'

# A draft the employee edits before anything is saved (CONVERSATION_SALES_PLAN.md, idea أ3)
RSpec.describe SalesCrm::ConversationSummary do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:client) { instance_double(SmartAssistant::LlmClient) }
  let(:answer) do
    { 'summary' => 'يريد 500 كرتون', 'objections' => 'السعر مرتفع', 'next_step' => 'إرسال عرض سعر',
      'suggested_amount' => '12,500', 'suggested_close_date' => (Date.current + 10).iso8601 }
  end

  before do
    allow(SmartAssistant::Config).to receive(:configured?).and_return(true)
    allow(SmartAssistant::LlmClient).to receive(:new).and_return(client)
    allow(client).to receive(:complete).and_return(answer)
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox, message_type: :incoming,
                     content: 'أبغى 500 كرتون')
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox, message_type: :outgoing,
                     content: 'السعر 25 للكرتون')
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox, message_type: :outgoing,
                     content: 'ملاحظة داخلية', private: true)
  end

  def summarize = described_class.new(account: account, conversation: conversation).perform

  it 'reads the public messages, counts the call as a Sales summary and returns the draft' do
    expect(summarize).to eq(summary: 'يريد 500 كرتون', objections: 'السعر مرتفع', next_step: 'إرسال عرض سعر',
                            suggested_amount: '12500', suggested_close_date: (Date.current + 10).iso8601)
    expect(SmartAssistant::LlmClient).to have_received(:new).with(account: account, kind: :crm_summary)
    expect(client).to have_received(:complete) do |messages:, **|
      expect(messages.last[:content]).to include('أبغى 500 كرتون', 'السعر 25 للكرتون')
      expect(messages.last[:content]).not_to include('ملاحظة داخلية')
    end
  end

  it 'drops an amount or a date the conversation did not give' do
    answer.merge!('suggested_amount' => '', 'suggested_close_date' => 'next week')
    expect(summarize).to include(suggested_amount: nil, suggested_close_date: nil)
  end

  it 'explains when the assistant is not set up' do
    allow(SmartAssistant::Config).to receive(:configured?).and_return(false)
    expect { summarize }.to raise_error(SalesCrm::ValidationError, I18n.t('sales_crm.errors.ai_not_configured'))
  end

  it 'says when the monthly limit renews once it is reached' do
    allow(SmartAssistant::Usage).to receive(:crm_limit_reached?).with(account).and_return(true)
    expect { summarize }.to raise_error(SalesCrm::ValidationError, /#{SalesCrm::Period.today.next_month.beginning_of_month.day}/)
    expect(client).not_to have_received(:complete)
  end
end
