class AddSmsSenderNameToCampaigns < ActiveRecord::Migration[7.2]
  def change
    add_column :campaigns, :sms_sender_name, :string
  end
end
