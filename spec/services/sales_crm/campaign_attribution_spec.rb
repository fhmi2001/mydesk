# Custom (MyDesk)
require 'rails_helper'

# Which campaign a new deal is credited to, set once when it is created (CONVERSATION_SALES_PLAN.md)
RSpec.describe SalesCrm::CampaignAttribution do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:contact) { create(:contact, account: account, phone_number: '+966545070901') }
  let(:sms_campaign) { create(:campaign, account: account) }

  def create_deal(attrs = {})
    SalesCrm::Deals::Create.new(account: account, user: user)
                           .perform({ title: 'x', amount: '100', close_date: Date.current + 30, pipeline_id: pipeline.id,
                                      contact_id: contact.id }.merge(attrs))
  end

  def recipient(phone, sent_at, campaign: sms_campaign, status: :sent)
    SmsCampaignRecipient.create!(account: account, campaign: campaign, phone_number: phone, status: status, sent_at: sent_at)
  end

  it 'credits a live chat campaign directly when the deal comes from its conversation' do
    chat_campaign = create(:campaign, account: account)
    conversation = create(:conversation, account: account, contact: contact, campaign: chat_campaign)
    recipient('966545070901', 2.days.ago)

    deal = create_deal(conversation_id: conversation.display_id)

    expect(deal).to have_attributes(campaign_id: chat_campaign.id, campaign_attribution: 'direct')
  end

  it 'credits the latest SMS campaign the customer got within the window, whatever way the number was written' do
    older = create(:campaign, account: account)
    recipient('+966545070901', 10.days.ago, campaign: older)
    recipient('0545070901', 3.days.ago)

    expect(create_deal).to have_attributes(campaign_id: sms_campaign.id, campaign_attribution: 'influenced')
  end

  it 'credits nothing past the window, for a failed message, or for another number' do
    account.update!(crm_sms_attribution_days: 7)
    recipient('966545070901', 9.days.ago)
    recipient('966545070901', 1.day.ago, status: :failed, campaign: create(:campaign, account: account))
    recipient('966500000000', 1.day.ago)

    expect(create_deal).to have_attributes(campaign_id: nil, campaign_attribution: nil)
  end
end
