# Custom (MyDesk): the account's smart assistant, its knowledge sources and their embedded chunks
class CreateSmartAssistants < ActiveRecord::Migration[7.1]
  def change
    create_assistants
    create_sources
    create_chunks
  end

  private

  def create_assistants
    create_table :smart_assistants do |t|
      t.bigint :account_id, null: false
      t.bigint :agent_bot_id
      t.boolean :enabled, null: false, default: false
      t.bigint :inbox_ids, array: true, null: false, default: []
      t.string :name, null: false
      t.string :tone, null: false, default: 'friendly'
      t.text :instructions
      t.string :reply_mode, null: false, default: 'always'
      t.boolean :handoff_when_unsure, null: false, default: true
      t.text :handoff_message
      t.integer :max_replies, null: false, default: 10
      t.timestamps
    end
    add_index :smart_assistants, :account_id, unique: true
  end

  def create_sources
    create_table :smart_assistant_sources do |t|
      t.bigint :account_id, null: false
      t.bigint :smart_assistant_id, null: false
      t.integer :kind, null: false
      t.integer :status, null: false, default: 0
      t.string :title, null: false
      t.text :content
      t.string :url
      t.string :error_message
      t.integer :chunks_count, null: false, default: 0
      t.datetime :synced_at
      t.timestamps
    end
    add_index :smart_assistant_sources, :smart_assistant_id
  end

  def create_chunks
    create_table :smart_assistant_chunks do |t|
      t.bigint :account_id, null: false
      t.bigint :smart_assistant_source_id, null: false
      t.text :content, null: false
      t.vector :embedding, limit: 1536
      t.timestamps
    end
    add_index :smart_assistant_chunks, :account_id
    add_index :smart_assistant_chunks, :smart_assistant_source_id
    add_index :smart_assistant_chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
