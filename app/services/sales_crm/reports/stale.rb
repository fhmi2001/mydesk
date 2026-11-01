# Custom (MyDesk): التقرير 3, الصفقات الراكدة والمتأخرة: the open deals that need moving today. Stale: no activity for the
# account's stale days (14 unless changed, or `days`; المؤشر 9). Overdue: the expected close date has passed. A deal can
# be both; «at risk» counts it once. A picture of now: no period, no previous period.
class SalesCrm::Reports::Stale < SalesCrm::Reports::Report
  KEY = 'stale'.freeze
  KINDS = %w[at_risk stale overdue].freeze
  ZERO = { count: 0, total_cents: 0 }.freeze
  QUIET_FIRST = Arel.sql('COALESCE(crm_deals.last_activity_at, crm_deals.created_at) ASC, crm_deals.amount_cents DESC')

  def self.list_filters = %i[product_id lead_source_id]
  def self.stage_filter? = true

  def initialize(account:, user:, **filters)
    super
    @days = filters[:days].to_i.positive? ? filters[:days].to_i.clamp(1, 365) : account.crm_stale_days_value
    @today = SalesCrm::Period.today
  end

  def build
    totals = KINDS.to_h { |kind| [kind.to_sym, figures(kind_scope(kind))] }
    { days: @days, totals: totals, empty: totals[:at_risk][:count].zero?, rows: lines(kind_scope('at_risk'), QUIET_FIRST),
      assignees: assignee_figures }
  end

  # cell: kind (at_risk, the default, stale or overdue) and assignee_id
  def drill_scope(cell)
    by_assignee(kind_scope(KINDS.include?(cell[:kind].to_s) ? cell[:kind].to_s : 'at_risk'), cell)
  end

  private

  def drill_order = QUIET_FIRST

  def kind_scope(kind)
    open = deals.open
    stale = SalesCrm::Metrics::DaysSinceActivity.stale(open, @days, today: @today)
    overdue = open.where(close_date: ...@today)
    { 'stale' => stale, 'overdue' => overdue }.fetch(kind) { stale.or(overdue) }
  end

  def figures(relation)
    count, cents = relation.pick(Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(crm_deals.amount_cents), 0)'))
    { count: count.to_i, total_cents: cents.to_i }
  end

  # Per employee: the three kinds side by side
  def assignee_figures
    return nil unless team_view?

    by_kind = KINDS.index_with { |kind| figures_by_assignee(kind_scope(kind)) }
    people = names(by_kind['at_risk'].keys)
    rows = by_kind['at_risk'].keys.map do |id|
      KINDS.to_h { |kind| [kind.to_sym, by_kind[kind].fetch(id, ZERO)] }.merge(assignee_id: id, name: people[id], cell: assignee_cell(id))
    end
    rows.sort_by { |row| -row[:at_risk][:total_cents] }
  end

  def figures_by_assignee(relation)
    relation.group(:assignee_id).pluck(:assignee_id, Arel.sql('COUNT(*)'), Arel.sql('SUM(crm_deals.amount_cents)'))
            .to_h { |id, count, cents| [id, { count: count.to_i, total_cents: cents.to_i }] }
  end
end
