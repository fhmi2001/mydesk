# Custom (MyDesk): numbers an SMS campaign sends to, with the delivery result of each one
class CreateSmsCampaignRecipients < ActiveRecord::Migration[7.2]
  def change
    create_table :sms_campaign_recipients do |t|
      t.references :account, null: false
      t.references :campaign, null: false, index: false
      t.string :phone_number, null: false
      t.integer :status, null: false, default: 0
      t.string :source_id
      t.text :error_message
      t.datetime :sent_at

      t.timestamps
    end
    add_index :sms_campaign_recipients, [:campaign_id, :phone_number], unique: true
    add_index :sms_campaign_recipients, [:campaign_id, :status]
  end
end
