# Custom (MyDesk): المؤشر 9, أيام منذ آخر نشاط: today − the day of the deal's last activity (its creation day when it has
# none), in Riyadh days. A deal is stale once that reaches the account's stale days (14 by default).
module SalesCrm::Metrics::DaysSinceActivity
  module_function

  def call(deal, today: SalesCrm::Period.today)
    last = deal.last_activity_at || deal.created_at
    (today - last.in_time_zone(SalesCrm::Period.zone).to_date).to_i
  end

  # The open deals with no activity for `days` days or more
  def stale(deals, days, today: SalesCrm::Period.today)
    cutoff = SalesCrm::Period.new(today - days, today - days).ends_at
    deals.open.where('COALESCE(crm_deals.last_activity_at, crm_deals.created_at) <= ?', cutoff)
  end
end
