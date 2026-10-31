# Custom (MyDesk): the Sales CRM (المبيعات): pipelines and stages, deals, tasks, notes and the deal activity log.
# Everything is scoped by account_id; amounts are integers in the currency's minor unit (halalas).
class CreateSalesCrmTables < ActiveRecord::Migration[7.1]
  def change
    create_pipelines
    create_stages
    create_deals
    create_tasks
    create_notes
    create_activities
  end

  private

  def create_pipelines
    create_table :crm_pipelines do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :name, null: false
      t.string :currency, null: false, default: 'SAR'
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :crm_pipelines, [:account_id, :name], unique: true
  end

  def create_stages
    create_table :crm_stages do |t|
      t.references :account, null: false, index: false
      t.references :pipeline, null: false, foreign_key: { to_table: :crm_pipelines, on_delete: :cascade }, index: false
      t.string :name, null: false
      t.integer :probability, null: false, default: 0
      t.integer :kind, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.string :color, null: false, default: '#94a3b8'
      t.timestamps
    end
    add_index :crm_stages, [:pipeline_id, :position]
    add_index :crm_stages, :account_id
    # exactly one won (kind 1) and one lost (kind 2) stage per pipeline
    add_index :crm_stages, :pipeline_id, unique: true, where: 'kind = 1', name: 'index_crm_stages_one_won_per_pipeline'
    add_index :crm_stages, :pipeline_id, unique: true, where: 'kind = 2', name: 'index_crm_stages_one_lost_per_pipeline'
    add_check_constraint :crm_stages, 'probability >= 0 AND probability <= 100', name: 'crm_stages_probability_range'
  end

  def create_deals # rubocop:disable Metrics/AbcSize, Metrics/MethodLength -- one table, many indexed columns
    create_table :crm_deals do |t|
      t.references :account, null: false, index: false
      t.references :pipeline, null: false, foreign_key: { to_table: :crm_pipelines }, index: false
      t.references :stage, null: false, foreign_key: { to_table: :crm_stages }, index: false
      t.references :contact, foreign_key: { on_delete: :nullify }, index: false
      t.string :contact_name_snapshot
      t.references :assignee, foreign_key: { to_table: :users, on_delete: :nullify }, index: false
      t.references :creator, foreign_key: { to_table: :users, on_delete: :nullify }, index: false
      t.references :conversation, foreign_key: { on_delete: :nullify }, index: false
      t.string :title, null: false
      t.string :title_normalized, null: false, default: ''
      t.string :contact_name_normalized, null: false, default: ''
      t.bigint :amount_cents, null: false, default: 0
      t.string :currency, null: false, default: 'SAR'
      t.date :close_date
      t.integer :status, null: false, default: 0
      t.datetime :won_at
      t.datetime :lost_at
      t.string :lost_reason
      t.integer :source, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.text :description
      t.integer :lock_version, null: false, default: 0
      t.datetime :discarded_at
      t.timestamps
    end
    add_index :crm_deals, [:account_id, :pipeline_id, :stage_id, :position]
    add_index :crm_deals, [:account_id, :contact_id]
    add_index :crm_deals, [:account_id, :assignee_id, :status]
    add_index :crm_deals, [:account_id, :status, :won_at]
    add_index :crm_deals, [:account_id, :status, :lost_at]
    add_index :crm_deals, [:account_id, :close_date]
    add_index :crm_deals, [:account_id, :discarded_at]
    add_index :crm_deals, :conversation_id
    add_check_constraint :crm_deals, 'amount_cents >= 0', name: 'crm_deals_amount_non_negative'
  end

  def create_tasks
    create_table :crm_tasks do |t|
      t.references :account, null: false, index: false
      t.string :title, null: false
      t.text :description
      t.datetime :due_at
      t.integer :status, null: false, default: 0
      t.datetime :done_at
      t.references :assignee, foreign_key: { to_table: :users, on_delete: :nullify }, index: false
      t.references :creator, foreign_key: { to_table: :users, on_delete: :nullify }, index: false
      t.references :contact, foreign_key: { on_delete: :nullify }, index: false
      t.references :deal, foreign_key: { to_table: :crm_deals, on_delete: :nullify }, index: false
      t.references :conversation, foreign_key: { on_delete: :nullify }, index: false
      t.datetime :reminded_at
      t.timestamps
    end
    add_index :crm_tasks, [:account_id, :assignee_id, :status, :due_at]
    add_index :crm_tasks, [:account_id, :deal_id]
    add_index :crm_tasks, [:account_id, :contact_id]
    add_index :crm_tasks, [:status, :due_at, :reminded_at], name: 'index_crm_tasks_for_reminders'
  end

  def create_notes
    create_table :crm_notes do |t|
      t.references :account, null: false, index: false
      t.references :deal, null: false, foreign_key: { to_table: :crm_deals, on_delete: :cascade }, index: false
      t.references :user, foreign_key: { on_delete: :nullify }, index: false
      t.text :content, null: false
      t.timestamps
    end
    add_index :crm_notes, [:account_id, :deal_id, :created_at]
  end

  def create_activities
    create_table :crm_activities do |t|
      t.references :account, null: false, index: false
      t.references :deal, null: false, foreign_key: { to_table: :crm_deals, on_delete: :cascade }, index: false
      t.references :user, foreign_key: { on_delete: :nullify }, index: false
      t.string :kind, null: false
      t.jsonb :data, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :crm_activities, [:account_id, :deal_id, :created_at]
    add_index :crm_activities, [:account_id, :kind, :created_at]
  end
end
