# Custom (MyDesk): one row per smart assistant call to OpenAI, with its tokens and cost
class CreateSmartAssistantUsages < ActiveRecord::Migration[7.1]
  def change
    create_table :smart_assistant_usages do |t|
      t.bigint :account_id, null: false
      t.integer :kind, null: false
      t.string :model, null: false
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.integer :cached_tokens, null: false, default: 0
      # US dollars; empty when the model has no known price
      t.decimal :cost, precision: 14, scale: 8
      t.datetime :created_at, null: false
    end
    add_index :smart_assistant_usages, [:account_id, :created_at]
  end
end
