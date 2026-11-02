# Custom (MyDesk): suggestions (اقتراحات) the employee accepts or dismisses: a new deal or a note from a conversation,
# and the follow-up, won and lost messages of a deal. At most one pending per conversation (new_deal, note) or per
# deal (follow_up, won_message, lost_question) and kind.
class CreateCrmSuggestions < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_suggestions do |t|
      t.bigint :account_id, null: false
      t.bigint :conversation_id
      t.bigint :contact_id
      t.bigint :deal_id
      t.integer :kind, null: false
      t.integer :status, null: false, default: 0
      t.integer :origin, null: false, default: 0
      t.jsonb :content, null: false, default: {}
      t.bigint :decided_by_id
      t.datetime :decided_at
      t.timestamps
    end
    add_suggestion_indexes
  end

  private

  def add_suggestion_indexes
    add_index :crm_suggestions, [:account_id, :conversation_id, :kind, :status]
    add_index :crm_suggestions, [:account_id, :deal_id, :kind, :status]
    add_index :crm_suggestions, [:conversation_id, :kind], unique: true, where: 'status = 0 AND kind IN (0, 1)',
                                                           name: 'index_crm_suggestions_one_pending_per_conversation'
    add_index :crm_suggestions, [:deal_id, :kind], unique: true, where: 'status = 0 AND kind IN (2, 3, 4)',
                                                   name: 'index_crm_suggestions_one_pending_per_deal'
    add_index :crm_suggestions, [:status, :decided_at]
  end
end
