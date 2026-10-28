require 'rails_helper'

RSpec.describe 'Smart assistant API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/integrations/smart_assistant" }

  around do |example|
    with_modified_env(SMART_ASSISTANT_OPENAI_API_KEY: 'test-key') { example.run }
  end

  it 'is for administrators only' do
    get base_url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'shows the defaults before anything is saved' do
    get base_url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('configured' => true)
    expect(response.parsed_body['assistant']).to include('enabled' => false, 'inbox_ids' => [], 'tone' => 'friendly')
    expect(response.parsed_body['usage']).to include('replies_this_month' => 0, 'monthly_limit' => 1000)
  end

  it "shows the account's own token usage and cost" do
    SmartAssistant::Usage.create!(account: account, kind: :reply, model: 'gpt-6-luna', input_tokens: 900, output_tokens: 60, cost: 0.00012)
    SmartAssistant::Usage.create!(account: create(:account), kind: :reply, model: 'gpt-6-luna', input_tokens: 5, cost: 1)

    get base_url, headers: admin.create_new_auth_token, as: :json

    tokens = response.parsed_body.dig('usage', 'tokens')
    expect(tokens['this_month']['reply']).to include('input_tokens' => 900, 'output_tokens' => 60, 'calls' => 1)
    expect(tokens['this_month']['reply']['cost'].to_d).to eq(BigDecimal('0.00012'))
    expect(tokens['months'].pluck('calls')).to eq([1])
  end

  it 'turns the assistant on for the chosen inboxes' do
    patch base_url, params: { smart_assistant: { enabled: true, inbox_ids: [inbox.id], tone: 'formal' } },
                    headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(inbox.reload.agent_bot).to eq(SmartAssistant.find_by(account: account).agent_bot)
    expect(response.parsed_body['assistant']).to include('enabled' => true, 'tone' => 'formal')
  end

  it 'explains why an inbox with another bot cannot be used' do
    create(:agent_bot_inbox, inbox: inbox, agent_bot: create(:agent_bot, account: account))

    patch base_url, params: { smart_assistant: { enabled: true, inbox_ids: [inbox.id] } },
                    headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['message']).to include(inbox.name)
    expect(SmartAssistant.find_by(account: account)).to be_nil
  end

  it 'answers a test conversation without touching real conversations' do
    responder = instance_double(SmartAssistant::Responder, perform: { reply: 'Hello!', handoff: false, sources: [] })
    allow(SmartAssistant::Responder).to receive(:new).and_return(responder)

    post "#{base_url}/test", params: { messages: [{ role: 'user', content: 'Hi' }] },
                             headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body).to eq('reply' => 'Hello!', 'handoff' => false, 'sources' => [])
    expect(SmartAssistant::Responder).to have_received(:new)
      .with(assistant: anything, messages: [{ role: :user, content: 'Hi' }], usage_kind: :test)
  end

  it 'rejects a test that does not end with the customer' do
    post "#{base_url}/test", params: { messages: [{ role: 'assistant', content: 'Hi' }] },
                             headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:bad_request)
  end

  describe 'knowledge sources' do
    it 'adds a question and answer and queues it for reading' do
      expect do
        post "#{base_url}/sources", params: { kind: 'faq', title: 'Delivery?', content: 'Two days' },
                                    headers: admin.create_new_auth_token, as: :json
      end.to have_enqueued_job(SmartAssistant::IngestSourceJob)

      expect(response.parsed_body).to include('kind' => 'faq', 'status' => 'pending', 'title' => 'Delivery?')
    end

    it 'uploads a document' do
      file = Rack::Test::UploadedFile.new(StringIO.new('Returns within 14 days'), 'text/plain', original_filename: 'returns.txt')

      post "#{base_url}/sources", params: { kind: 'document', file: file }, headers: admin.create_new_auth_token

      expect(response.parsed_body).to include('kind' => 'document', 'title' => 'returns.txt')
    end

    it 'refuses a page address that is not a web link' do
      post "#{base_url}/sources", params: { kind: 'website', url: 'ftp://shop' }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'lists and deletes only the account sources' do
      source = SmartAssistant.for_account(account).tap(&:save!).sources.create!(kind: :text, title: 'Policy', content: 'x')

      get "#{base_url}/sources", headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['payload'].pluck('id')).to eq([source.id])

      delete "#{base_url}/sources/#{source.id}", headers: admin.create_new_auth_token, as: :json
      expect(SmartAssistant::Source.exists?(source.id)).to be(false)
    end
  end
end
