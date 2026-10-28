require 'rails_helper'

RSpec.describe SmartAssistant::LlmClient do
  let(:account) { create(:account) }
  let(:client) { described_class.new(account: account, kind: :knowledge) }
  let(:context) { instance_double(RubyLLM::Context) }
  let(:tokens) { RubyLLM::Tokens.new(input: 120, output: 0) }
  let(:embedding) do
    instance_double(RubyLLM::Embedding, vectors: [[0.1], [0.2]], tokens: tokens, cost: instance_double(RubyLLM::Cost, total: 0.0000024))
  end

  before do
    allow(Llm::Config).to receive(:with_api_key).and_yield(context)
    allow(context).to receive(:embed).and_return(embedding)
  end

  it 'records the tokens and cost of every call for the account' do
    expect(client.embed(%w[one two])).to eq([[0.1], [0.2]])

    usage = SmartAssistant::Usage.last
    expect(usage).to have_attributes(account_id: account.id, kind: 'knowledge', model: 'text-embedding-3-small',
                                     input_tokens: 120, output_tokens: 0, cost: BigDecimal('0.0000024'))
  end

  it 'tries again when the connection to OpenAI drops' do
    calls = 0
    allow(context).to receive(:embed) do
      calls += 1
      calls == 1 ? raise(Faraday::SSLError, 'unexpected eof') : embedding
    end

    expect(client.embed(['one'])).to eq([[0.1], [0.2]])
    expect(calls).to eq(2)
  end
end
