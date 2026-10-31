# Custom (MyDesk): the account's day boundaries for "today" / "overdue" (its reporting time zone, else Riyadh)
module SalesCrm::TimeZone
  DEFAULT = 'Asia/Riyadh'.freeze

  module_function

  def for(account)
    ActiveSupport::TimeZone[account.reporting_timezone.presence || DEFAULT] || ActiveSupport::TimeZone[DEFAULT]
  end

  def today_range(account, now = Time.current)
    zone = self.for(account)
    local = now.in_time_zone(zone)
    local.all_day
  end
end
