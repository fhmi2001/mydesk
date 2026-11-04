# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SalesCrm::Deal do
  let(:account) { create(:account) }
  let(:pipeline) { create(:crm_pipeline, account: account) }

  it 'converts a major-unit amount to cents' do
    deal = build(:crm_deal, account: account, pipeline: pipeline, amount: '50000')
    expect(deal.amount_cents).to eq(5_000_000)
    expect(deal.amount).to eq(BigDecimal(50_000))
  end

  it 'rejects a negative amount' do
    deal = build(:crm_deal, account: account, pipeline: pipeline, amount_cents: -1)
    expect(deal).not_to be_valid
  end

  it 'rejects an amount above the cap' do
    deal = build(:crm_deal, account: account, pipeline: pipeline, amount_cents: described_class::MAX_AMOUNT_CENTS + 1)
    expect(deal).not_to be_valid
  end

  it 'fills the normalized search columns and the contact snapshot' do
    contact = create(:contact, account: account, name: 'أَحْمَد العُمري')
    deal = create(:crm_deal, account: account, pipeline: pipeline, title: 'Package ٥٠', contact: contact)
    expect(deal.title_normalized).to eq('package 50')
    expect(deal.contact_name_normalized).to eq('احمد العمري')
    expect(deal.contact_name_snapshot).to eq('أَحْمَد العُمري')
  end

  it 'keeps the snapshot name after the contact is deleted' do
    contact = create(:contact, account: account, name: 'سارة')
    deal = create(:crm_deal, account: account, pipeline: pipeline, contact: contact)
    contact.destroy!
    expect(deal.reload.contact_id).to be_nil
    expect(deal.display_contact_name).to eq('سارة')
  end

  describe 'conversation links' do
    let(:conversation) { create(:conversation, account: account) }

    it 'is followed in its origin conversation until it moves on' do
      deal = create(:crm_deal, account: account, conversation: conversation)
      expect(deal.active_conversation).to eq(conversation)
    end

    it 'keeps a campaign and how the campaign led to it' do
      campaign = create(:campaign, account: account)
      deal = create(:crm_deal, account: account, campaign: campaign, campaign_attribution: :influenced)
      expect(deal.reload).to have_attributes(campaign: campaign, campaign_attribution: 'influenced')
    end

    it 'starts its last touch at its creation' do
      freeze_time do
        expect(create(:crm_deal, account: account).last_touch_at).to eq(Time.current)
      end
    end
  end
end
