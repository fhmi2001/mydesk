# Custom (MyDesk): handset delivery result of each campaign number, read back from the SMS provider on demand
class AddDeliveryStatusToSmsCampaignRecipients < ActiveRecord::Migration[7.2]
  def change
    change_table :sms_campaign_recipients, bulk: true do |t|
      # The provider's delivery status code (Deewan: 1 delivered, 2 undelivered, ...); nil until checked
      t.integer :delivery_status
      t.decimal :delivery_price, precision: 10, scale: 4
      t.datetime :delivery_checked_at
    end
  end
end
