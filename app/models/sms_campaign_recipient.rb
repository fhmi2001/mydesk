# == Schema Information
#
# Table name: sms_campaign_recipients
#
#  id                  :bigint           not null, primary key
#  delivery_checked_at :datetime
#  delivery_price      :decimal(10, 4)
#  delivery_status     :integer
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

  # Deewan's handset delivery status codes (https://developer.deewan.sa/reference/getting-sms-details)
  DELIVERY_STATUSES = {
    1 => 'delivered', 2 => 'undelivered', 3 => 'sent', 4 => 'buffered', 5 => 'blocked',
    16 => 'rejected', 17 => 'in_progress', 34 => 'expired', 1200 => 'unknown'
  }.freeze
  DELIVERED = 1
  # These will not change any more, so they are not asked about again
  FINAL_DELIVERY_STATUSES = [1, 2, 5, 16, 34].freeze

  # Sent numbers whose handset delivery may still change
  scope :awaiting_delivery_result, lambda {
    sent.where(delivery_status: nil).or(sent.where.not(delivery_status: FINAL_DELIVERY_STATUSES))
  }

  def delivery_status_name
    return if delivery_status.nil?

    DELIVERY_STATUSES.fetch(delivery_status, 'unknown')
  end

  validates :phone_number, presence: true, uniqueness: { scope: :campaign_id }

  # source_id is the provider's SMS id for this number; provider_request_id identifies the API call (Deewan requestId)
  def mark_sent!(source_id, request_id: nil)
    update!(status: :sent, source_id: source_id, provider_request_id: request_id, sent_at: Time.current, error_message: nil)
  end

  def mark_failed!(error_message, request_id: nil)
    update!(status: :failed, error_message: error_message, provider_request_id: request_id)
  end
end
