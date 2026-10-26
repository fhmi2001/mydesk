require 'rails_helper'

# Custom (MyDesk): SMS campaigns send from the sender name chosen in the campaign
describe Sms::OneoffSmsCampaignService do
  let(:account) { create(:account) }
  let(:sms_channel) do
    create(:channel_sms, account: account, phone_number: 'MyStore', provider: 'deewan',
                         provider_config: { 'api_key' => 'deewan-key', 'sender_names' => ['MyStore-OTP'] })
  end
  let(:label) { create(:label, account: account) }
  let(:campaign) do
    create(:campaign, inbox: sms_channel.inbox, account: account, message: 'your otp is 01234',
                      sms_sender_name: 'MyStore-OTP', scheduled_at: 1.day.from_now,
                      audience: [{ type: 'Label', id: label.id }])
  end

  it 'sends every message with the campaign sender name' do
    contact = create(:contact, account: account, phone_number: '+966552889989')
    contact.update_labels([label.title])
    request = stub_request(:post, 'https://apis.deewan.sa/sms/v1/messages')
              .with(body: hash_including('senderName' => 'MyStore-OTP', 'recipients' => '966552889989'))
              .to_return(status: 200, body: { replyCode: 0, data: { SentSMSIDs: [{ SMSId: 'id-1' }] } }.to_json,
                         headers: { 'Content-Type' => 'application/json' })

    described_class.new(campaign: campaign).perform

    expect(request).to have_been_requested
    expect(campaign.reload).to be_completed
  end
end
