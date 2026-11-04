# Custom (MyDesk): the target of a period. Targets are monthly per employee (gap-analysis.md): a quarter is
# the sum of its months, the team is the sum of its employees, and a period that covers part of a month takes that
# month's target in proportion to its days (10 of 30 days → a third).
module SalesCrm::Metrics::Target
  module_function

  # user_ids: nil for the whole team
  def cents(account, period, user_ids: nil)
    overlaps = period.month_overlaps
    targets = account.crm_targets.where(period_start: overlaps.map(&:first))
    targets = targets.where(user_id: user_ids) unless user_ids.nil?
    by_month = targets.group(:period_start).sum(:amount_cents)
    overlaps.sum do |month, days, month_days|
      (by_month.fetch(month, 0) * days / month_days.to_r).round
    end
  end
end
