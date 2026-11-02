# Custom (MyDesk): التقرير 2, الصفقات المتوقع إغلاقها خلال الفترة: the open deals whose expected close date falls in the
# period (the whole month unless a range is given), soonest first, with their count, value, weighted value and
# average probability. Grouped by employee in the team view.
class SalesCrm::Reports::Closing < SalesCrm::Reports::Report
  KEY = 'closing'.freeze
  CLOSE_ORDER = { close_date: :asc, amount_cents: :desc, id: :asc }.freeze

  def self.list_filters = %i[product_id lead_source_id]
  def self.stage_filter? = true
  def self.forward? = true

  def build
    groups = grouped(base, assignee_id: 'crm_deals.assignee_id')
    totals = sum(groups)
    { totals: totals, empty: totals[:count].zero?, rows: lines(base, CLOSE_ORDER), assignees: assignee_rows(groups) }
  end

  def drill_scope(cell) = by_assignee(base, cell)

  private

  def base = deals.open.where(close_date: period.dates)

  def drill_order = CLOSE_ORDER
end
