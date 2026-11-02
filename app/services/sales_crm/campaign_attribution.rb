# Custom (MyDesk): which campaign a new deal is credited to (CONVERSATION_SALES_PLAN.md, idea د3), set once by
# SalesCrm::Deals::Create and never changed. Direct: the deal's conversation came from a live chat campaign. Influenced:
# the customer's mobile got an SMS campaign message within the account's window before the deal (the latest one wins).
# Numbers are matched in the forms they are stored in (+9665…, 9665…, 05…), without writing to the recipients.
module SalesCrm::CampaignAttribution
  module_function

  # { campaign_id:, campaign_attribution: } or {}
  def for(account, contact:, conversation:)
    return { campaign_id: conversation.campaign_id, campaign_attribution: :direct } if conversation&.campaign_id

    campaign_id = sms_campaign_id(account, contact)
    campaign_id ? { campaign_id: campaign_id, campaign_attribution: :influenced } : {}
  end

  def sms_campaign_id(account, contact)
    number = Sms::SaudiMobileNumber.normalize(contact&.phone_number)
    return unless number

    SmsCampaignRecipient.where(account_id: account.id, status: :sent, phone_number: forms(number),
                               sent_at: account.crm_sms_attribution_days_value.days.ago..)
                        .order(sent_at: :desc).pick(:campaign_id)
  end

  # 9665XXXXXXXX as +9665XXXXXXXX, 9665XXXXXXXX, 05XXXXXXXX and 5XXXXXXXX
  def forms(number)
    local = number.delete_prefix(Sms::SaudiMobileNumber::COUNTRY_CODE)
    ["+#{number}", number, "0#{local}", local]
  end
end
