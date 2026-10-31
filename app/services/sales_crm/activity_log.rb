# Custom (MyDesk): appends one line to a deal's activity log. Anything a person does on the deal also moves its
# last_activity_at, which the stale-deals and data-quality reports read; nothing from Chatwoot conversations does.
module SalesCrm::ActivityLog
  module_function

  def record(deal:, kind:, user:, data: {})
    activity = SalesCrm::Activity.create!(account_id: deal.account_id, deal: deal, user: user, kind: kind, data: data)
    deal.update_column(:last_activity_at, activity.created_at) if user # rubocop:disable Rails/SkipsModelValidations
    activity
  end
end
