# Custom (MyDesk): what links a deal to the conversations (docs/mydesk/CONVERSATION_SALES_PLAN.md, phase 1).
# active_conversation_id is the conversation the deal is followed in now (conversation_id stays the origin);
# last_message_at is an employee's latest reply there, last_touch_at the later of it and last_activity_at;
# campaign_id / campaign_attribution are set once, when the deal is created.
class AddConversationLinksToCrmDeals < ActiveRecord::Migration[7.1]
  def change
    change_table :crm_deals, bulk: true do |t|
      t.bigint :active_conversation_id
      t.datetime :last_message_at
      t.datetime :last_touch_at
      t.bigint :campaign_id
      t.integer :campaign_attribution
    end
    add_index :crm_deals, [:account_id, :active_conversation_id, :status]
    add_index :crm_deals, [:account_id, :last_touch_at]
    add_index :crm_deals, [:account_id, :campaign_id]
  end
end
