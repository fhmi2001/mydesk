# Custom (MyDesk): every webhook a connected Salla store sends (new orders, status changes, ...), kept per account
# so order notifications (WhatsApp / SMS) can be built on top of them
class CreateSallaEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :salla_events do |t|
      t.bigint :account_id, null: false
      t.bigint :hook_id
      t.string :merchant_id, null: false
      t.string :event, null: false
      t.string :order_id
      t.string :order_reference
      t.string :status_name
      t.string :customer_name
      t.string :customer_mobile
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end

    add_index :salla_events, [:account_id, :created_at]
    add_index :salla_events, [:account_id, :event]
  end
end
