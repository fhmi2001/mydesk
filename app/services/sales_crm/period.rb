# Custom (MyDesk): a report period: whole days, from `first` to `last`, in Riyadh time (SalesCrm::TimeZone). Every
# report and metric reads its boundaries from here, so a deal won at 00:30 on the 1st in Riyadh (21:30 the day before
# in UTC) always lands in the new month.
class SalesCrm::Period
  attr_reader :first, :last

  def self.zone = SalesCrm::TimeZone.for

  def self.today(now = Time.current) = now.in_time_zone(zone).to_date

  # From YYYY-MM-DD strings; a missing start is the first of this month, a missing end is today
  def self.parse(from, to, now: Time.current)
    today = today(now)
    first = parse_date(from) || today.beginning_of_month
    last = parse_date(to) || today
    new(first, [last, first].max)
  end

  def self.month(date) = new(date.beginning_of_month, date.end_of_month)
  def self.quarter(date) = new(date.beginning_of_quarter, date.end_of_quarter)

  def self.parse_date(value)
    Date.iso8601(value.to_s) if value.present?
  rescue Date::Error
    nil
  end

  def initialize(first, last)
    @first = first.to_date
    @last = last.to_date
  end

  # Times, for created_at / won_at / lost_at
  def range
    zone = self.class.zone
    zone.local(first.year, first.month, first.day)..zone.local(last.year, last.month, last.day).end_of_day
  end

  def begins_at = range.begin
  def ends_at = range.end

  # Dates, for close_date
  def dates = first..last

  def days = (last - first).to_i + 1

  # The same number of days just before this period, for comparisons
  def previous = self.class.new(first - days, first - 1)

  # Each month the period touches: [first day of the month, days of the period in it, days in the month]
  def month_overlaps
    (first.beginning_of_month..last).select { |d| d.day == 1 }.map do |month|
      overlap = ([last, month.end_of_month].min - [first, month].max).to_i + 1
      [month, overlap, month.end_of_month.day]
    end
  end

  def ==(other) = other.is_a?(self.class) && other.first == first && other.last == last
end
