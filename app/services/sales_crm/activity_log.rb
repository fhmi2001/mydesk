# Custom (MyDesk): appends one line to a deal's activity log. Anything a person does on the deal also moves its
# last_activity_at and its last_touch_at (the later of it and an employee's last reply in the deal's conversation,
# which the stale-deals and data-quality reports read). The system's own lines (user nil) move neither.
module SalesCrm::ActivityLog
  module_function

  def record(deal:, kind:, user:, data: {})
    activity = SalesCrm::Activity.create!(account_id: deal.account_id, deal: deal, user: user, kind: kind, data: data)
    deal.update_columns(last_activity_at: activity.created_at, last_touch_at: activity.created_at) if user # rubocop:disable Rails/SkipsModelValidations
    activity
  end
end
