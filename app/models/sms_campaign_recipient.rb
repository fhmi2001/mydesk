# == Schema Information
#
# Table name: sms_campaign_recipients
#
#  id                  :bigint           not null, primary key
#  error_message       :text
#  phone_number        :string           not null
#  sent_at             :datetime
#  status              :integer          default("queued"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  campaign_id         :bigint           not null
#  provider_request_id :string
#  source_id           :string
#
# Indexes
#
#  index_sms_campaign_recipients_on_account_id                    (account_id)
#  index_sms_campaign_recipients_on_campaign_id_and_phone_number  (campaign_id,phone_number) UNIQUE
#  index_sms_campaign_recipients_on_campaign_id_and_status        (campaign_id,status)
#

# Custom (MyDesk): one phone number of an SMS campaign and what happened when it was sent
class SmsCampaignRecipient < ApplicationRecord
  belongs_to :account
  belongs_to :campaign

  enum status: { queued: 0, sent: 1, failed: 2 }

  validates :phone_number, presence: true, uniqueness: { scope: :campaign_id }

  # source_id is the provider's SMS id for this number; provider_request_id identifies the API call (Deewan requestId)
  def mark_sent!(source_id, request_id: nil)
    update!(status: :sent, source_id: source_id, provider_request_id: request_id, sent_at: Time.current, error_message: nil)
  end

  def mark_failed!(error_message, request_id: nil)
    update!(status: :failed, error_message: error_message, provider_request_id: request_id)
  end
end
