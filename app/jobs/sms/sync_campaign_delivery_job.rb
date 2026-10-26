# Custom (MyDesk): checks the handset delivery of an SMS campaign's numbers in the background
class Sms::SyncCampaignDeliveryJob < ApplicationJob
  queue_as :low

  def perform(campaign)
    Sms::DeliveryStatusSyncService.new(campaign: campaign).perform
  end
end
