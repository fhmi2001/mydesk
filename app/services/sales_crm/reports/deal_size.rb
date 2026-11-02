# Custom (MyDesk): التقرير 18, اتجاه متوسط حجم الصفقة (للمدير): are our deals getting bigger or smaller? The average won
# deal (المؤشر 7, won deals without an amount left out) month by month, or quarter by quarter past two years, for the
# team and each employee. The period is this year so far unless a range is given: a trend needs months.
class SalesCrm::Reports::DealSize < SalesCrm::Reports::Report
  KEY = 'deal_size'.freeze

  def self.admin_only? = true
  def self.list_filters = %i[product_id lead_source_id]

  def initialize(account:, user:, **filters)
    super
    @period = SalesCrm::Period.new(today.beginning_of_year, today, zone) if filters[:from].blank?
  end

  def build
    average = SalesCrm::Metrics::AverageDealSize.call(deals, period)
    { interval: interval, totals: { average_cents: average, won_count: sized(period).count },
      previous_totals: { average_cents: SalesCrm::Metrics::AverageDealSize.call(deals, period.previous) },
      empty: average.nil?, buckets: series(deals), assignees: assignee_series }
  end

  # cell: from / to (a bucket) and assignee_id
  def drill_scope(cell) = by_assignee(sized(window_for(cell)), cell)

  private

  def drill_order = { won_at: :desc, id: :desc }

  def sized(window, relation = deals) = relation.won.where(won_at: window.range).where('crm_deals.amount_cents > 0')

  def interval = period.days > 731 ? 'quarter' : 'month'

  def bucket_start(date) = interval == 'quarter' ? date.beginning_of_quarter : date.beginning_of_month
  def bucket_end(start) = interval == 'quarter' ? start.end_of_quarter : start.end_of_month

  # [{ bucket, average_cents, count, cell }] for every bucket of the period
  def series(relation, cell = {})
    by_bucket = sized(period, relation).pluck(:won_at, :amount_cents).group_by { |at, _| bucket_start(local_date(at)) }
    bucket_cells.map do |start, bucket_cell|
      amounts = by_bucket.fetch(start, []).map(&:last)
      { bucket: start.iso8601, count: amounts.size, average_cents: SalesCrm::Metrics::Ratio.average_cents(amounts.sum, amounts.size),
        cell: bucket_cell.merge(cell) }
    end
  end

  def assignee_series
    return nil unless team_view?

    ids = sized(period).distinct.pluck(:assignee_id)
    people = names(ids)
    ids.map do |id|
      mine = deals.where(assignee_id: id)
      { assignee_id: id, name: people[id], average_cents: SalesCrm::Metrics::AverageDealSize.call(mine, period),
        count: sized(period, mine).count, cell: assignee_cell(id), buckets: series(mine, assignee_cell(id)) }
    end
  end
end
