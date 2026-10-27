require 'rails_helper'

RSpec.describe 'Performance report API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:path) { "/api/v2/accounts/#{account.id}/performance_report" }
  let(:range) { { since: 7.days.ago.to_i, until: Time.current.to_i } }

  it 'returns the current and previous period with channels' do
    get path, params: range, headers: admin.create_new_auth_token

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.keys).to contain_exactly('current', 'previous', 'channels', 'unanswered_now')
  end

  it 'needs a date range' do
    get path, headers: admin.create_new_auth_token

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects agents without report access' do
    get path, params: range, headers: agent.create_new_auth_token

    expect(response).to have_http_status(:unauthorized)
  end
end
