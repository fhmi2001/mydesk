# Custom (MyDesk): التقرير 17, الإيراد حسب المنتج والقطاع والمنطقة (للمدير): where does revenue come from? The value won in
# the period grouped by `group_by` (product, industry or region; «not set» for deals without one), each group's share
# of the total, and its growth against the period before.
class SalesCrm::Reports::Revenue < SalesCrm::Reports::Report
  KEY = 'revenue'.freeze
  GROUPS = { 'product' => :product_id, 'industry' => :industry_id, 'region' => :region_id }.freeze

  def self.admin_only? = true

  def initialize(account:, user:, **filters)
    super
    @group = GROUPS.key?(filters[:group_by].to_s) ? filters[:group_by].to_s : 'product'
  end

  def build
    current = sums(period)
    previous = sums(period.previous)
    total = current.values.sum { |s| s[:cents] }
    { group_by: @group, totals: { won_cents: total, won_count: current.values.sum { |s| s[:count] } },
      previous_totals: { won_cents: previous.values.sum { |s| s[:cents] } }, empty: current.empty?,
      rows: rows(current, previous, total) }
  end

  # cell: the group's column (product_id, industry_id or region_id; 'none' too) and assignee_id
  def drill_scope(cell) = by_lists(by_assignee(won(period), cell), cell)

  private

  def column = GROUPS.fetch(@group)

  def won(window) = deals.won.where(won_at: window.range)

  # group id => { count, cents }
  def sums(window)
    won(window).group(column).pluck(column, Arel.sql('COUNT(*)'), Arel.sql('SUM(crm_deals.amount_cents)'))
               .to_h { |id, count, cents| [id, { count: count, cents: cents.to_i }] }
  end

  def rows(current, previous, total)
    labels = item_names(current.keys)
    result = current.map do |id, sum|
      before = previous.dig(id, :cents).to_i
      { id: id, name: labels[id], count: sum[:count], total_cents: sum[:cents], previous_cents: before,
        share: SalesCrm::Metrics::Ratio.percent(sum[:cents], total),
        growth: before.zero? ? nil : SalesCrm::Metrics::Ratio.percent(sum[:cents] - before, before), cell: { column => id || NONE } }
    end
    result.sort_by { |row| -row[:total_cents] }
  end
end
