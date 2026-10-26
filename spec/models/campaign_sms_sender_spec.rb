require 'rails_helper'

# Custom (MyDesk): sender name choice and "send now" for SMS campaigns
RSpec.describe Campaign do
  let(:account) { create(:account) }
  let(:sms_channel) do
    create(:channel_sms, account: account, phone_number: 'MyStore', provider: 'deewan',
                         provider_config: { 'api_key' => 'deewan-key', 'sender_names' => ['MyStore-OTP'] })
  end
  let(:sms_inbox) { sms_channel.inbox }

  describe 'sms_sender_name' do
    it 'accepts an approved sender name of the inbox' do
      campaign = build(:campaign, account: account, inbox: sms_inbox, sms_sender_name: 'MyStore-OTP')

      expect(campaign).to be_valid
    end

    it 'rejects a sender name the inbox does not have' do
      campaign = build(:campaign, account: account, inbox: sms_inbox, sms_sender_name: 'OtherBrand')

      expect(campaign).not_to be_valid
      expect(campaign.errors[:sms_sender_name]).to be_present
    end
  end

  describe 'sending now' do
    it 'queues the campaign right away when it is due' do
      expect do
        create(:campaign, account: account, inbox: sms_inbox, scheduled_at: Time.current)
      end.to have_enqueued_job(Campaigns::TriggerOneoffCampaignJob)
    end

    it 'leaves future campaigns to the scheduler' do
      expect do
        create(:campaign, account: account, inbox: sms_inbox, scheduled_at: 1.day.from_now)
      end.not_to have_enqueued_job(Campaigns::TriggerOneoffCampaignJob)
    end
  end
end
