# Custom (MyDesk): the Sales section's day boundaries, for "today" / "overdue" and every report period: the time zone
# the account picks in the general settings (account.reporting_timezone, the one Chatwoot's own reports use), Riyadh
# until it picks one (docs/reports/gap-analysis.md).
module SalesCrm::TimeZone
  DEFAULT = 'Asia/Riyadh'.freeze

  module_function

  def for(account = nil)
    name = account&.reporting_timezone
    (ActiveSupport::TimeZone[name] if name.present?) || default
  end

  def default = ActiveSupport::TimeZone[DEFAULT]

  def today_range(account, now = Time.current)
    now.in_time_zone(self.for(account)).all_day
  end
end
