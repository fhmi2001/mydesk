require 'rails_helper'

# Custom (MyDesk): campaigns sent to typed/imported numbers, with a recorded result per number
describe Sms::OneoffSmsCampaignService do
  let(:account) { create(:account) }
  let(:sms_channel) do
    create(:channel_sms, account: account, phone_number: 'MyStore', provider: 'deewan', provider_config: { 'api_key' => 'deewan-key' })
  end
  let(:api_url) { 'https://apis.deewan.sa/sms/v1/messages' }
  let(:campaign) do
    create(:campaign, account: account, inbox: sms_channel.inbox, message: 'Sale today', scheduled_at: 1.day.from_now,
                      recipient_numbers: %w[0551234567 966551234567 0559999999 bad])
  end

  def deewan_reply(code:, message:, id: nil, request_id: nil)
    data = id ? { SentSMSIDs: [{ SMSId: id }] } : {}
    body = { replyCode: code, replyMessage: message, requestId: request_id, data: data }
    { status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end

  it 'stores the cleaned, unique numbers when the campaign is created' do
    expect(campaign.sms_campaign_recipients.pluck(:phone_number)).to contain_exactly('966551234567', '966559999999')
    expect(campaign.sms_delivery_stats).to eq(total: 2, queued: 2, sent: 0, failed: 0, delivered: 0)
  end

  it 'sends to every number and records what Deewan answered' do
    stub_request(:post, api_url).with(body: hash_including('recipients' => '966551234567'))
                                .to_return(deewan_reply(code: 0, message: 'Request handled successfully', id: 'sms-1', request_id: 'req-1'))
    stub_request(:post, api_url).with(body: hash_including('recipients' => '966559999999'))
                                .to_return(deewan_reply(code: -17, message: 'Not enough credits', request_id: 'req-2'))

    described_class.new(campaign: campaign).perform

    sent = campaign.sms_campaign_recipients.find_by(phone_number: '966551234567')
    failed = campaign.sms_campaign_recipients.find_by(phone_number: '966559999999')
    expect(sent).to have_attributes(status: 'sent', source_id: 'sms-1', provider_request_id: 'req-1')
    expect(failed).to have_attributes(status: 'failed', error_message: 'Not enough credits', provider_request_id: 'req-2')
    expect(campaign.reload).to be_completed
    expect(campaign.sms_delivery_stats).to eq(total: 2, queued: 0, sent: 1, failed: 1, delivered: 0)
  end

  it 'records label contacts as recipients too' do
    label = create(:label, account: account)
    create(:contact, account: account, phone_number: '+966558888888').update_labels([label.title])
    campaign.update!(audience: [{ type: 'Label', id: label.id }])
    stub_request(:post, api_url).to_return(deewan_reply(code: 0, message: 'ok', id: 'sms-x'))

    described_class.new(campaign: campaign).perform

    expect(campaign.sms_campaign_recipients.pluck(:phone_number)).to include('+966558888888')
    expect(campaign.sms_delivery_stats[:sent]).to eq(3)
  end
end
