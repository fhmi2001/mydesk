# Custom (MyDesk): the deal fields the sales reports need (docs/reports/gap-analysis.md):
# - list values: lead source, product, competitor, region, industry (crm_list_items)
# - forecast_category: set only when the employee picks one; otherwise derived from the probability
# - probability_override: this deal's own probability; empty means the stage's
# - last_activity_at: the latest Sales activity on the deal (never Chatwoot messages)
# Backfills last_activity_at from the activity log, and gives any open deal without an owner its creator.
class AddReportFieldsToCrmDeals < ActiveRecord::Migration[7.1]
  LIST_COLUMNS = %i[lead_source_id product_id competitor_id region_id industry_id].freeze

  def up
    change_table :crm_deals, bulk: true do |t|
      LIST_COLUMNS.each { |column| t.bigint column }
      t.integer :forecast_category
      t.integer :probability_override
      t.datetime :last_activity_at
    end
    add_check_constraint :crm_deals, 'probability_override IS NULL OR (probability_override >= 0 AND probability_override <= 100)',
                         name: 'crm_deals_probability_override_range'
    LIST_COLUMNS.each { |column| add_index :crm_deals, [:account_id, column] }
    add_index :crm_deals, [:account_id, :last_activity_at]

    execute <<~SQL.squish
      UPDATE crm_deals SET last_activity_at = COALESCE(
        (SELECT MAX(crm_activities.created_at) FROM crm_activities WHERE crm_activities.deal_id = crm_deals.id), crm_deals.created_at)
    SQL
    execute 'UPDATE crm_deals SET assignee_id = creator_id WHERE assignee_id IS NULL AND creator_id IS NOT NULL AND status = 0'
  end

  def down
    remove_index :crm_deals, [:account_id, :last_activity_at]
    LIST_COLUMNS.each { |column| remove_index :crm_deals, [:account_id, column] }
    remove_check_constraint :crm_deals, name: 'crm_deals_probability_override_range'
    change_table :crm_deals, bulk: true do |t|
      t.remove(*LIST_COLUMNS, :forecast_category, :probability_override, :last_activity_at)
    end
  end
end
