class AddProviderRequestIdToSmsCampaignRecipients < ActiveRecord::Migration[7.2]
  def change
    add_column :sms_campaign_recipients, :provider_request_id, :string
  end
end
