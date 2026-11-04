# Custom (MyDesk): a report period: whole days, from `first` to `last`, in the account's time zone (SalesCrm::TimeZone,
# Riyadh until the account picks one). Every report and metric reads its boundaries from here, so a deal won at 00:30
# on the 1st in that time zone (21:30 the day before in UTC, for Riyadh) always lands in the new month.
class SalesCrm::Period
  attr_reader :first, :last, :zone

  def self.today(zone = SalesCrm::TimeZone.default, now: Time.current) = now.in_time_zone(zone).to_date

  # From YYYY-MM-DD strings; a missing start is the first of this month, a missing end is today
  def self.parse(from, to, zone: SalesCrm::TimeZone.default, now: Time.current)
    today = today(zone, now: now)
    first = parse_date(from) || today.beginning_of_month
    last = parse_date(to) || today
    new(first, [last, first].max, zone)
  end

  def self.month(date, zone = SalesCrm::TimeZone.default) = new(date.beginning_of_month, date.end_of_month, zone)
  def self.quarter(date, zone = SalesCrm::TimeZone.default) = new(date.beginning_of_quarter, date.end_of_quarter, zone)

  def self.parse_date(value)
    Date.iso8601(value.to_s) if value.present?
  rescue Date::Error
    nil
  end

  def initialize(first, last, zone = SalesCrm::TimeZone.default)
    @first = first.to_date
    @last = last.to_date
    @zone = zone
  end

  # Times, for created_at / won_at / lost_at
  def range
    zone.local(first.year, first.month, first.day)..zone.local(last.year, last.month, last.day).end_of_day
  end

  def begins_at = range.begin
  def ends_at = range.end

  # Dates, for close_date
  def dates = first..last

  def days = (last - first).to_i + 1

  # The same number of days just before this period, for comparisons; whole months compare with the months before them
  # (October with September, not with 31 days from 31 August)
  def previous
    return self.class.new(first << months, first - 1, zone) if whole_months?

    self.class.new(first - days, first - 1, zone)
  end

  def whole_months? = first.day == 1 && last == last.end_of_month

  def months = ((last.year * 12) + last.month) - ((first.year * 12) + first.month) + 1

  # Each month the period touches: [first day of the month, days of the period in it, days in the month]
  def month_overlaps
    (first.beginning_of_month..last).select { |d| d.day == 1 }.map do |month|
      overlap = ([last, month.end_of_month].min - [first, month].max).to_i + 1
      [month, overlap, month.end_of_month.day]
    end
  end

  def ==(other) = other.is_a?(self.class) && other.first == first && other.last == last && other.zone == zone
end
