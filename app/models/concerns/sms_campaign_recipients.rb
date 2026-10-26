# Custom (MyDesk): SMS campaigns can send to their own list of numbers (typed or imported from Excel)
# besides contact labels. The cleaned numbers are stored as SmsCampaignRecipient rows, which also keep
# the delivery result of every number.
module SmsCampaignRecipients
  extend ActiveSupport::Concern

  INSERT_BATCH_SIZE = 1000

  included do
    has_many :sms_campaign_recipients, dependent: :delete_all

    # Raw numbers sent when creating the campaign; they are re-cleaned here, never trusted as given
    attr_accessor :recipient_numbers

    after_create :store_sms_recipients, if: -> { recipient_numbers.present? }
  end

  def sms_campaign?
    inbox&.inbox_type == 'Sms'
  end

  def sms_delivery_stats
    counts = sms_campaign_recipients.group(:status).count
    delivered = sms_campaign_recipients.where(delivery_status: SmsCampaignRecipient::DELIVERED).count
    { total: counts.values.sum, queued: counts['queued'].to_i, sent: counts['sent'].to_i, failed: counts['failed'].to_i,
      delivered: delivered }
  end

  private

  def store_sms_recipients
    numbers = Sms::RecipientListBuilder.new(recipient_numbers).perform.valid_numbers
    now = Time.current
    numbers.each_slice(INSERT_BATCH_SIZE) do |batch|
      rows = batch.map do |number|
        { account_id: account_id, campaign_id: id, phone_number: number, status: :queued, created_at: now, updated_at: now }
      end
      # Numbers are already cleaned and unique, and lists can hold tens of thousands of rows
      SmsCampaignRecipient.insert_all(rows) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
