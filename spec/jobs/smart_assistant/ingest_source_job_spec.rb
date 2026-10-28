require 'rails_helper'

RSpec.describe SmartAssistant::IngestSourceJob do
  let(:account) { create(:account) }
  let(:assistant) { SmartAssistant.for_account(account).tap(&:save!) }
  let(:client) { instance_double(SmartAssistant::LlmClient) }

  before do
    allow(SmartAssistant::LlmClient).to receive(:new).and_return(client)
    allow(client).to receive(:embed) { |texts| texts.map { Array.new(1536, 0.1) } }
  end

  it 'splits a long text into embedded passages and marks it ready' do
    source = assistant.sources.create!(kind: :text, title: 'Policy', content: "#{'أ' * 1000}\n\n#{'ب' * 1000}")

    described_class.perform_now(source.id)

    expect(source.reload).to have_attributes(status: 'ready', chunks_count: 2, error_message: nil)
    expect(source.chunks.pluck(:account_id).uniq).to eq([account.id])
  end

  it 'replaces the passages of an earlier sync' do
    source = assistant.sources.create!(kind: :faq, title: 'Delivery?', content: 'Two days')
    2.times { described_class.perform_now(source.id) }

    expect(source.chunks.count).to eq(1)
    expect(source.chunks.first.content).to eq("Delivery?\nTwo days")
  end

  it 'marks a page that cannot be read as failed' do
    source = assistant.sources.create!(kind: :website, title: 'Shop', url: 'https://shop.example.com/policy')
    allow(SafeFetch).to receive(:fetch).and_raise(SafeFetch::HttpError, '404 Not Found')

    described_class.perform_now(source.id)

    expect(source.reload).to have_attributes(status: 'failed', error_message: '404 Not Found')
  end
end
