require 'rails_helper'

# Custom (MyDesk): the dashboard sends recipient_numbers at the top level of the JSON body, like every other field
RSpec.describe 'Creating an SMS campaign with typed or imported numbers', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:sms_channel) do
    create(:channel_sms, account: account, phone_number: 'MyStore', provider: 'deewan', provider_config: { 'api_key' => 'key' })
  end

  it 'stores the cleaned numbers on the campaign' do
    post "/api/v1/accounts/#{account.id}/campaigns",
         headers: admin.create_new_auth_token,
         params: { title: 'Offer', message: 'Hello', inbox_id: sms_channel.inbox.id, scheduled_at: 1.day.from_now.iso8601,
                   recipient_numbers: %w[0551234567 966551234567 551234568] },
         as: :json

    expect(response).to have_http_status(:success)
    campaign = account.campaigns.find_by!(display_id: response.parsed_body['id'])
    expect(campaign.sms_campaign_recipients.pluck(:phone_number)).to contain_exactly('966551234567', '966551234568')
    expect(response.parsed_body['sms_stats']).to include('total' => 2, 'queued' => 2)
  end
end
