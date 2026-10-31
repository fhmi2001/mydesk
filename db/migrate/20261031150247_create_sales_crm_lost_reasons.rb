# Custom (MyDesk): the account's list of lost reasons for the Sales CRM, and free-text notes on a lost deal
class CreateSalesCrmLostReasons < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_lost_reasons do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :crm_lost_reasons, [:account_id, :name], unique: true
    add_index :crm_lost_reasons, [:account_id, :position]

    add_column :crm_deals, :lost_note, :text
  end
end
