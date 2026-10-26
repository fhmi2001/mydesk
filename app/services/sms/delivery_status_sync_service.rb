# Custom (MyDesk): asks the SMS provider whether each sent number of a campaign received its message.
# Numbers with a final result (delivered, undelivered, blocked, ...) are not asked about again.
class Sms::DeliveryStatusSyncService
  LOCK_KEY = 'SMS_CAMPAIGN_DELIVERY_SYNC::%<campaign_id>s'.freeze
  LOCK_TIMEOUT = 30.minutes

  pattr_initialize [:campaign!]

  def self.lock_key(campaign)
    format(LOCK_KEY, campaign_id: campaign.id)
  end

  def self.running?(campaign)
    Redis::LockManager.new.locked?(lock_key(campaign))
  end

  # Takes the lock now, so the page shows the check as running before the job starts; false if it already runs
  def self.start(campaign)
    return false unless Redis::LockManager.new.lock(lock_key(campaign), LOCK_TIMEOUT)

    Sms::SyncCampaignDeliveryJob.perform_later(campaign)
    true
  end

  def perform
    campaign.sms_campaign_recipients.awaiting_delivery_result.find_each { |recipient| sync(recipient) }
  ensure
    Redis::LockManager.new.unlock(self.class.lock_key(campaign))
  end

  private

  def sync(recipient)
    message_id = recipient.source_id.presence || recipient.provider_request_id
    return if message_id.blank?

    details = campaign.inbox.channel.sms_delivery_details(message_id)
    return if details.nil? || details[:status].nil?

    recipient.update!(delivery_status: details[:status], delivery_price: details[:price], delivery_checked_at: Time.current)
  rescue StandardError => e
    # One number failing to answer should not stop the others from being checked
    Rails.logger.error("[SMS Campaign #{campaign.id}] Delivery status check failed for #{recipient.phone_number}: #{e.message}")
  end
end
