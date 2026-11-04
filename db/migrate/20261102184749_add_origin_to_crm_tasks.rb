# Custom (MyDesk): where a task came from (manual / stage_rule / follow_up / automation), so the stage rules and
# the follow-up never open a second task of the same origin for a deal
class AddOriginToCrmTasks < ActiveRecord::Migration[7.1]
  def change
    add_column :crm_tasks, :origin, :integer, null: false, default: 0
    add_index :crm_tasks, [:account_id, :deal_id, :origin, :status]
  end
end
