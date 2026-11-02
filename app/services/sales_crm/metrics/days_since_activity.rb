# Custom (MyDesk): المؤشر 9, أيام منذ آخر نشاط: today − the day of the deal's last touch, in the account's days
# (SalesCrm::TimeZone). The last touch (crm_deals.last_touch_at) is the later of a person's last activity on the deal
# and an employee's last reply in its conversation (decision ح, docs/mydesk/CONVERSATION_SALES_PLAN.md); the creation
# day when it has neither. A deal is stale once that reaches the account's stale days (14 by default). The one stale
# condition the reports share.
module SalesCrm::Metrics::DaysSinceActivity
  module_function

  def call(deal, zone: SalesCrm::TimeZone.default, today: SalesCrm::Period.today(zone))
    (today - touched_at(deal).in_time_zone(zone).to_date).to_i
  end

  def touched_at(deal)
    deal.last_touch_at || [deal.last_activity_at, deal.last_message_at].compact.max || deal.created_at
  end

  # The open deals with no touch for `days` days or more
  def stale(deals, days, zone: SalesCrm::TimeZone.default, today: SalesCrm::Period.today(zone))
    cutoff = SalesCrm::Period.new(today - days, today - days, zone).ends_at
    open = deals.open
    open.where(last_touch_at: ..cutoff).or(open.where(last_touch_at: nil, created_at: ..cutoff))
  end

  # Quietest first
  ORDER = { last_touch_at: :asc, amount_cents: :desc }.freeze
end
