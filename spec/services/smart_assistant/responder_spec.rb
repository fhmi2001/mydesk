require 'rails_helper'

RSpec.describe SmartAssistant::Responder do
  let(:account) { create(:account, name: 'Bajaba') }
  let(:assistant) { SmartAssistant.for_account(account).tap { |record| record.update!(instructions: 'Always greet warmly') } }
  let(:client) { instance_double(SmartAssistant::LlmClient) }
  let(:messages) { [{ role: :user, content: 'Do you deliver to Jeddah?' }] }
  let(:near) { Array.new(1536) { |i| i.zero? ? 1.0 : 0.0 } }
  let(:far) { Array.new(1536) { |i| i == 1 ? 1.0 : 0.0 } }

  before do
    allow(SmartAssistant::LlmClient).to receive(:new).and_return(client)
    allow(client).to receive(:embed_one).and_return(near)
    allow(client).to receive(:complete).and_return({ 'reply' => 'Yes, in 3 days', 'handoff' => false, 'passages_used' => [1] })
  end

  it 'gives the model its own account passages, closest first, and cites the ones it used' do
    delivery = assistant.sources.create!(kind: :faq, title: 'Delivery', content: 'All cities', status: :ready)
    delivery.chunks.create!(account_id: account.id, content: 'We deliver to every Saudi city', embedding: near)
    unrelated = assistant.sources.create!(kind: :text, title: 'Jobs', content: 'Careers', status: :ready)
    unrelated.chunks.create!(account_id: account.id, content: 'We are hiring', embedding: far)
    other = SmartAssistant.for_account(create(:account)).tap(&:save!)
    other.sources.create!(kind: :text, title: 'Other', content: 'x', status: :ready)
         .chunks.create!(account_id: other.account_id, content: 'Another store', embedding: near)

    result = described_class.new(assistant: assistant, messages: messages).perform

    expect(result).to eq(reply: 'Yes, in 3 days', handoff: false, sources: [{ id: delivery.id, title: 'Delivery' }], sales_lead: nil)
    expect(client).to have_received(:complete) do |instructions:, **|
      expect(instructions).to include('[1] We deliver to every Saudi city', '[2] We are hiring', 'Bajaba', 'Always greet warmly')
      expect(instructions).not_to include('Another store')
    end
  end

  describe 'a clear intent to buy (CONVERSATION_SALES_PLAN.md, idea أ2)' do
    let(:lead) { { 'detected' => true, 'product' => ' كراتين ', 'quantity' => '500', 'city' => 'جدة', 'summary' => 'يطلب سعر 500 كرتون' } }

    it 'is asked for in the same call, as a required part of the strict schema' do
      described_class.new(assistant: assistant, messages: messages).perform

      expect(client).to have_received(:complete) do |instructions:, schema:, **|
        expect(schema[:schema][:required]).to include('sales_lead')
        expect(schema[:schema][:properties][:sales_lead][:required]).to eq(%w[detected product quantity city summary])
        expect(instructions).to include('sales_lead')
      end
    end

    it 'comes back with the reply when the model detects one' do
      allow(client).to receive(:complete).and_return({ 'reply' => 'أكيد', 'handoff' => false, 'passages_used' => [], 'sales_lead' => lead })

      result = described_class.new(assistant: assistant, messages: messages).perform

      expect(result[:sales_lead]).to eq(product: 'كراتين', quantity: '500', city: 'جدة', summary: 'يطلب سعر 500 كرتون')
    end

    it 'is nil when there is none' do
      allow(client).to receive(:complete)
        .and_return({ 'reply' => 'أكيد', 'handoff' => false, 'passages_used' => [], 'sales_lead' => lead.merge('detected' => false) })

      expect(described_class.new(assistant: assistant, messages: messages).perform[:sales_lead]).to be_nil
    end
  end

  it 'still replies when the knowledge base is empty' do
    result = described_class.new(assistant: assistant, messages: messages).perform

    expect(result[:sources]).to be_empty
    expect(client).not_to have_received(:embed_one)
  end
end
