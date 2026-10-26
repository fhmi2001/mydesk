require 'rails_helper'

describe Sms::DeliveryStatusSyncService do
  let(:account) { create(:account) }
  let(:sms_channel) do
    create(:channel_sms, account: account, phone_number: 'MyStore', provider: 'deewan', provider_config: { 'api_key' => 'deewan-key' })
  end
  let(:campaign) do
    create(:campaign, account: account, inbox: sms_channel.inbox, scheduled_at: 1.day.from_now,
                      recipient_numbers: %w[0551234567 0559999999 0558888888])
  end
  let(:recipients) { campaign.sms_campaign_recipients.order(:phone_number).to_a }

  def stub_details(sms_id, body:, status: 200)
    stub_request(:get, "https://apis.deewan.sa/sms/v1/messages/#{sms_id}")
      .with(headers: { 'Authorization' => 'Bearer deewan-key' })
      .to_return(status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def details_body(sms_id, status)
    { replyCode: 0, data: [{ Id: sms_id, Status: status, price: 0.03 }] }
  end

  before do
    recipients[0].mark_sent!('sms-1')
    recipients[1].mark_sent!('sms-2')
    recipients[2].mark_failed!('Not enough credits')
  end

  it 'stores the delivery status of every sent number' do
    stub_details('sms-1', body: details_body('sms-1', 1))
    stub_details('sms-2', body: details_body('sms-2', 2))

    described_class.new(campaign: campaign).perform

    expect(recipients[0].reload).to have_attributes(delivery_status_name: 'delivered', delivery_price: 0.03)
    expect(recipients[1].reload.delivery_status_name).to eq('undelivered')
    expect(recipients[2].reload.delivery_status).to be_nil
    expect(campaign.sms_delivery_stats[:delivered]).to eq(1)
  end

  it 'does not ask again about numbers with a final result' do
    recipients[0].update!(delivery_status: 1)
    recipients[1].update!(delivery_status: 17)
    stub_details('sms-2', body: details_body('sms-2', 1))

    described_class.new(campaign: campaign).perform

    expect(a_request(:get, %r{messages/sms-1})).not_to have_been_made
    expect(recipients[1].reload.delivery_status_name).to eq('delivered')
  end

  it 'keeps checking the other numbers when one lookup fails' do
    stub_details('sms-1', status: 400, body: { replyCode: -1, replyMessage: 'Bad Request' })
    stub_details('sms-2', body: details_body('sms-2', 1))

    described_class.new(campaign: campaign).perform

    expect(recipients[0].reload.delivery_status).to be_nil
    expect(recipients[1].reload.delivery_status_name).to eq('delivered')
  end

  it 'runs once at a time and releases the lock when done' do
    expect(described_class.start(campaign)).to be(true)
    expect(described_class.start(campaign)).to be(false)
    expect(described_class).to be_running(campaign)

    stub_details('sms-1', body: details_body('sms-1', 1))
    stub_details('sms-2', body: details_body('sms-2', 1))
    described_class.new(campaign: campaign).perform

    expect(described_class).not_to be_running(campaign)
  end
end
