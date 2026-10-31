# Custom (MyDesk): appends one line to a deal's activity log
module SalesCrm::ActivityLog
  module_function

  def record(deal:, kind:, user:, data: {})
    SalesCrm::Activity.create!(account_id: deal.account_id, deal: deal, user: user, kind: kind, data: data)
  end
end
