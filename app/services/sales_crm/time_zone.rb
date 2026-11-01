# Custom (MyDesk): the Sales section's day boundaries, for "today" / "overdue" and every report period. Always Riyadh
# (docs/reports/gap-analysis.md, question 9): the reports never follow Chatwoot's own reporting time zone.
module SalesCrm::TimeZone
  DEFAULT = 'Asia/Riyadh'.freeze

  module_function

  def for(_account = nil)
    ActiveSupport::TimeZone[DEFAULT]
  end

  def today_range(account, now = Time.current)
    now.in_time_zone(self.for(account)).all_day
  end
end
