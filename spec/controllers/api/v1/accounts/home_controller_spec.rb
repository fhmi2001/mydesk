require 'rails_helper'

# Custom (MyDesk): the home screen's count of open conversations waiting an hour or more for a reply
RSpec.describe 'Home screen API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:path) { "/api/v1/accounts/#{account.id}/home/waiting" }

  # waiting_since is set on create (Conversation#ensure_waiting_since), so each one is set afterwards
  def conversation_waiting(since, account: self.account, status: :open)
    create(:conversation, account: account, status: status).tap { |c| c.update!(waiting_since: since) }
  end

  it 'counts the open conversations waiting an hour or more' do
    2.times { conversation_waiting(2.hours.ago) }
    conversation_waiting(10.minutes.ago)
    conversation_waiting(nil)
    conversation_waiting(3.hours.ago, status: :resolved)
    conversation_waiting(3.hours.ago, account: create(:account))

    get path, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('late_count' => 2)
  end

  it 'rejects agents, as the other support reports do' do
    get path, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
