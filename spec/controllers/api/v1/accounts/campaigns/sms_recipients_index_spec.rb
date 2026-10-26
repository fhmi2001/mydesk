require 'rails_helper'

RSpec.describe 'SMS campaign recipients list API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:sms_channel) { create(:channel_sms, account: account, provider: 'deewan', provider_config: { 'api_key' => 'key' }) }
  let(:campaign) do
    create(:campaign, account: account, inbox: sms_channel.inbox, scheduled_at: 1.day.from_now,
                      recipient_numbers: %w[0551234567 0559999999])
  end
  let(:path) { "/api/v1/accounts/#{account.id}/campaigns/#{campaign.display_id}/sms_recipients" }

  it 'rejects agents' do
    get path, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'lists the numbers with their result and provider ids' do
    campaign.sms_campaign_recipients.find_by(phone_number: '966551234567').mark_sent!('sms-1', request_id: 'req-1')

    get path, headers: admin.create_new_auth_token, as: :json

    body = response.parsed_body
    expect(body['meta']).to include('count' => 2, 'page' => 1)
    expect(body['payload'].first).to include('phone_number' => '966551234567', 'status' => 'sent',
                                             'source_id' => 'sms-1', 'provider_request_id' => 'req-1')
  end

  it 'starts checking delivery of the sent numbers' do
    campaign.sms_campaign_recipients.find_by(phone_number: '966551234567').mark_sent!('sms-1')

    expect do
      post "#{path}/sync_delivery", headers: admin.create_new_auth_token, as: :json
    end.to have_enqueued_job(Sms::SyncCampaignDeliveryJob).with(campaign)

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body['delivery_sync_running']).to be(true)
  ensure
    Redis::LockManager.new.unlock(Sms::DeliveryStatusSyncService.lock_key(campaign))
  end

  it 'does not start a check when no number awaits a delivery result' do
    expect do
      post "#{path}/sync_delivery", headers: admin.create_new_auth_token, as: :json
    end.not_to have_enqueued_job(Sms::SyncCampaignDeliveryJob)
  end

  it 'filters by status' do
    campaign.sms_campaign_recipients.find_by(phone_number: '966559999999').mark_failed!('Not enough credits')

    get path, headers: admin.create_new_auth_token, params: { status: 'failed' }

    expect(response.parsed_body['payload'].pluck('phone_number')).to eq(['966559999999'])
  end
end
