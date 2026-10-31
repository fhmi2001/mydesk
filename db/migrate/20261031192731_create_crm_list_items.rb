# Custom (MyDesk): the Sales CRM's managed lists (lead source, product, competitor, region, industry), one table with
# a list key. Items are archived, never deleted, so a deal keeps its value in old reports.
class CreateCrmListItems < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_list_items do |t|
      t.bigint :account_id, null: false
      t.string :list, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.datetime :archived_at
      t.timestamps
    end
    add_index :crm_list_items, [:account_id, :list, :position]
    add_index :crm_list_items, 'account_id, list, lower(name)', unique: true, where: 'archived_at IS NULL',
                                                                name: 'index_crm_list_items_unique_active_name'
  end
end
