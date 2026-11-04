# Custom (MyDesk): per-stage follow-up rules. silence_followup turns on the follow-up when the customer goes quiet;
# followup_task_days / followup_task_title create a task when a deal enters the stage.
class AddFollowupRulesToCrmStages < ActiveRecord::Migration[7.1]
  def change
    change_table :crm_stages, bulk: true do |t|
      t.boolean :silence_followup, null: false, default: false
      t.integer :followup_task_days
      t.string :followup_task_title
    end
  end
end
