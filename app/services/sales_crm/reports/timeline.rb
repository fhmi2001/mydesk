# Custom (MyDesk): deals created, won and lost per day / week / month across the period (empty buckets included)
class SalesCrm::Reports::Timeline < SalesCrm::Reports::Base
  INTERVALS = %w[day week month].freeze
  MAX_BUCKETS = 400

  def perform(interval: 'day')
    interval = 'day' unless INTERVALS.include?(interval.to_s)
    series = series_for(interval)
    buckets(interval).map do |bucket|
      key = bucket.to_date.to_s
      { bucket: key, created: series[:created][key] || 0, won: series[:won][key] || 0, lost: series[:lost][key] || 0,
        won_total_cents: series[:won_totals][key] || 0 }
    end
  end

  private

  def series_for(interval)
    won = deals.won.where(won_at: range)
    { created: bucketed(deals.where(created_at: range), :created_at, interval),
      won: bucketed(won, :won_at, interval), lost: bucketed(deals.lost.where(lost_at: range), :lost_at, interval),
      won_totals: bucketed(won, :won_at, interval, sum: :amount_cents) }
  end

  def zone
    @zone ||= SalesCrm::TimeZone.for(account)
  end

  # { 'YYYY-MM-DD' => count or sum } with the bucket start in the account's zone
  def bucketed(relation, column, interval, sum: nil)
    zone_name = ActiveRecord::Base.connection.quote(zone.tzinfo.name)
    trunc = Arel.sql("DATE_TRUNC('#{interval}', crm_deals.#{column} AT TIME ZONE 'UTC' AT TIME ZONE #{zone_name})")
    grouped = relation.group(trunc)
    rows = sum ? grouped.sum(sum) : grouped.count
    rows.transform_keys { |time| time.to_date.to_s }
  end

  def buckets(interval)
    cursor = from.in_time_zone(zone).public_send("beginning_of_#{interval}")
    finish = to.in_time_zone(zone)
    result = []
    while cursor <= finish && result.size < MAX_BUCKETS
      result << cursor
      cursor += 1.public_send(interval)
    end
    result
  end
end
