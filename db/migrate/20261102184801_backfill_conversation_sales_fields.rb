# Custom (MyDesk): fills the new conversation fields for the deals and stages that exist already. The active
# conversation starts as the origin one, the last touch as the last activity (or the creation), and the silence
# follow-up is on for the «تم إرسال العرض» and «تفاوض» stages wherever they still carry those names.
# Plain table models, so later changes to SalesCrm::Deal or SalesCrm::Stage cannot break this migration; the
# column copies skip validations on purpose (no record changes meaning).
class BackfillConversationSalesFields < ActiveRecord::Migration[7.1]
  FOLLOWUP_STAGES = ['تم إرسال العرض', 'تفاوض'].freeze

  # rubocop:disable Rails/SkipsModelValidations
  def up
    deals = table_model('crm_deals')
    deals.where(active_conversation_id: nil).where.not(conversation_id: nil)
         .update_all(active_conversation_id: deals.arel_table[:conversation_id])
    deals.where(last_touch_at: nil).where.not(last_activity_at: nil).update_all(last_touch_at: deals.arel_table[:last_activity_at])
    deals.where(last_touch_at: nil).update_all(last_touch_at: deals.arel_table[:created_at])
    table_model('crm_stages').where(name: FOLLOWUP_STAGES, kind: 0).update_all(silence_followup: true)
  end
  # rubocop:enable Rails/SkipsModelValidations

  def down; end

  private

  def table_model(table)
    Class.new(ApplicationRecord) { self.table_name = table }
  end
end
