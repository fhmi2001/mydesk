# Custom (MyDesk): التقرير 10, نسبة الفوز: from which employee, product or lead source do we win most (المؤشر 4)? Won ÷
# closed in the period, by count and by value, grouped by `group_by` (assignee, product or lead_source; an employee has
# no colleagues to compare with, so they start on product). Against the period before.
class SalesCrm::Reports::WinRates < SalesCrm::Reports::Report
  KEY = 'win_rate'.freeze
  GROUPS = { 'assignee' => :assignee_id, 'product' => :product_id, 'lead_source' => :lead_source_id }.freeze
  STATUS_SQL = SalesCrm::Deal.statuses.slice('won', 'lost').freeze

  def self.list_filters = %i[product_id lead_source_id]

  def initialize(account:, user:, **filters)
    super
    @group = GROUPS.key?(filters[:group_by].to_s) ? filters[:group_by].to_s : default_group
  end

  def build
    totals = SalesCrm::Metrics::WinRate.call(deals, period)
    { group_by: @group, totals: totals, previous_totals: SalesCrm::Metrics::WinRate.call(deals, period.previous),
      empty: (totals[:won_count] + totals[:lost_count]).zero?, rows: rows }
  end

  # cell: status (won, lost, or closed for both), and the group's column (assignee_id, product_id, lead_source_id)
  def drill_scope(cell)
    status = cell[:status].to_s
    relation = STATUS_SQL.key?(status) ? closed_as(status) : closed
    by_lists(by_assignee(relation, cell), cell)
  end

  private

  def default_group = team_view? ? 'assignee' : 'product'

  def closed_as(status)
    status == 'won' ? deals.won.where(won_at: period.range) : deals.lost.where(lost_at: period.range)
  end

  def closed = closed_as('won').or(closed_as('lost'))

  def rows
    column = GROUPS.fetch(@group)
    data = closed.group(column).pluck(column, *%w[won lost].flat_map { |s| aggregates(s) })
    labels = labels_for(data.map(&:first))
    result = data.map { |id, *figures| row(id, labels[id], column, figures) }
    result.sort_by { |r| [-r[:by_count].to_f, -(r[:won_count] + r[:lost_count])] }
  end

  def labels_for(ids) = @group == 'assignee' ? names(ids) : item_names(ids)

  def row(id, name, column, (won_count, won_cents, lost_count, lost_cents))
    { id: id, name: name, won_count: won_count, won_cents: won_cents.to_i, lost_count: lost_count, lost_cents: lost_cents.to_i,
      by_count: SalesCrm::Metrics::WinRate.by_count(won_count, lost_count),
      by_value: SalesCrm::Metrics::WinRate.by_value(won_cents, lost_cents), cell: { column => id || NONE } }
  end

  def aggregates(status)
    filter = "FILTER (WHERE crm_deals.status = #{STATUS_SQL.fetch(status)})"
    [Arel.sql("COUNT(*) #{filter}"), Arel.sql("COALESCE(SUM(crm_deals.amount_cents) #{filter}, 0)")]
  end
end
