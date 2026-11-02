# Custom (MyDesk): what kind of follow-up a task is (task / call / meeting), for the activity reports
class AddKindToCrmTasks < ActiveRecord::Migration[7.1]
  def change
    add_column :crm_tasks, :kind, :integer, null: false, default: 0
    add_index :crm_tasks, [:account_id, :assignee_id, :kind]
  end
end
