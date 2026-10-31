# Custom (MyDesk): a sales target (هدف) per employee per month, in the account's currency minor unit.
# The team target is the sum of the employees' targets and is never stored.
class CreateCrmTargets < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_targets do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.bigint :amount_cents, null: false, default: 0
      t.timestamps
    end
    add_index :crm_targets, [:account_id, :user_id, :period_start], unique: true
    add_index :crm_targets, [:account_id, :period_start]
    add_check_constraint :crm_targets, 'period_end >= period_start', name: 'crm_targets_period_order'
    add_check_constraint :crm_targets, 'amount_cents >= 0', name: 'crm_targets_amount_non_negative'
  end
end
