# Custom (MyDesk): what every report of CRM_REPORTS_PLAN.md phase 4 shares. One class per report serves both roles:
# the deals come through SalesCrm::Visibility (Reports::Base), so an employee only ever counts their own and the team
# view (rows per employee) is for administrators. Each report answers `perform` with
#   { key, period, previous_period, currency, team, empty, totals, previous_totals, rows, ... }
# and every number in it carries a `cell`: the filters `drill(cell)` applies to list the deals behind it, from the
# same relation the number was counted on, so the list always adds up to the number that was clicked.
class SalesCrm::Reports::Report < SalesCrm::Reports::Base
  PER_PAGE = 50
  # Deals listed inside a report; the rest are a click away, through drill. A printout (`full`) lists them all, up to
  # PRINT_LIMIT.
  LIST_LIMIT = 100
  PRINT_LIMIT = 2000
  NONE = 'none'.freeze
  # COUNT, value, the raw weighted sum (÷ 100 once summed, so rows and totals round the same way) and the probabilities
  PROBABILITY = 'COALESCE(crm_deals.probability_override, crm_stages.probability)'.freeze
  AGGREGATES = ['COUNT(*)', 'COALESCE(SUM(crm_deals.amount_cents), 0)',
                "COALESCE(SUM(#{SalesCrm::Metrics::WeightedPipeline::EXPRESSION}), 0)",
                "COALESCE(SUM(#{PROBABILITY}), 0)"].map { |sql| Arel.sql(sql) }.freeze

  class << self
    # The managed-list filters a report takes (product, lead source), and whether it takes a stage
    def list_filters = []
    def stage_filter? = false
    # Reports about what is still to close default to the whole month, not the month so far
    def forward? = false
  end

  attr_reader :cell

  # filters: those of Reports::Base, plus product_id, lead_source_id, stage_id, and cell (a hash) for drill
  def initialize(account:, user:, **filters)
    super
    @period = forward_period(filters) if self.class.forward?
    @list_filters = filters.slice(*self.class.list_filters).compact_blank.transform_values(&:to_i)
    @stage_id = filters[:stage_id].presence&.to_i if self.class.stage_filter?
    @cell = (filters[:cell] || {}).to_h.symbolize_keys
    @list_limit = ActiveModel::Type::Boolean.new.cast(filters[:full]) ? PRINT_LIMIT : LIST_LIMIT
  end

  def perform
    body = build
    { key: self.class::KEY, period: dates(period), previous_period: body.key?(:previous_totals) ? dates(period.previous) : nil,
      currency: currency, team: team_view? }.merge(body)
  end

  # The deals behind one number, a page at a time
  def drill(page: 1)
    relation = drill_scope(cell)
    { total_count: relation.count, total_cents: relation.sum('crm_deals.amount_cents'),
      items: relation.includes(:stage, :assignee, :contact).reorder(drill_order).page(page.to_i.clamp(1, 10_000)).per(PER_PAGE)
                     .map { |deal| line(deal) } }
  end

  private

  # Administrators without an employee filter see the team, row per employee
  def team_view? = admin? && assignee_id.nil?

  def deals
    relation = super
    relation = relation.where(@list_filters) if @list_filters.any?
    relation = relation.where(stage_id: @stage_id) if @stage_id
    relation
  end

  def drill_order = { amount_cents: :desc, id: :desc }

  def forward_period(filters)
    first = SalesCrm::Period.parse_date(filters[:from]) || SalesCrm::Period.today.beginning_of_month
    last = SalesCrm::Period.parse_date(filters[:to]) || first.end_of_month
    SalesCrm::Period.new(first, [last, first].max)
  end

  def dates(window) = { from: window.first.iso8601, to: window.last.iso8601 }

  # A cell's employee: absent for all, 'none' for deals without one. Only the team view narrows by it.
  def by_assignee(relation, cell)
    return relation unless team_view? && cell.key?(:assignee_id)

    value = cell[:assignee_id].to_s
    relation.where(assignee_id: value == NONE ? nil : value.to_i)
  end

  def assignee_cell(id) = { assignee_id: id || NONE }

  # id => display name, for the employees in rows (nil, a deal without an owner, has no name)
  def names(ids)
    account.users.where(id: ids.compact.uniq).to_h { |u| [u.id, u.available_name] }
  end

  # One deal as a report lists it
  def line(deal, today: SalesCrm::Period.today)
    { id: deal.id, title: deal.title, amount_cents: deal.amount_cents, currency: deal.currency, status: deal.status,
      close_date: deal.close_date, won_at: deal.won_at, lost_at: deal.lost_at, lost_reason: deal.lost_reason,
      probability: deal.effective_probability, forecast_category: deal.effective_forecast_category }.merge(line_context(deal, today))
  end

  def line_context(deal, today)
    { stage: { id: deal.stage_id, name: deal.stage&.name, color: deal.stage&.color },
      assignee: deal.assignee && { id: deal.assignee.id, name: deal.assignee.available_name },
      contact_name: deal.display_contact_name, last_activity_at: deal.last_activity_at,
      days_since_activity: SalesCrm::Metrics::DaysSinceActivity.call(deal, today: today),
      days_overdue: days_overdue(deal, today) }
  end

  def days_overdue(deal, today)
    (today - deal.close_date).to_i if deal.open? && deal.close_date && deal.close_date < today
  end

  def lines(relation, order)
    relation.includes(:stage, :assignee, :contact).reorder(order).limit(@list_limit).map { |deal| line(deal) }
  end

  # [{ <name>: value, ..., count, total_cents, weighted_raw, probability_sum }], one per combination of the columns,
  # given as name: SQL
  def grouped(relation, **columns)
    names = columns.keys
    sql = columns.values.map { |c| Arel.sql(c) }
    relation.joins(:stage).group(*sql).pluck(*sql, *AGGREGATES).map do |row|
      *keys, count, cents, raw, probabilities = row
      names.zip(keys).to_h.merge(count: count.to_i, total_cents: cents.to_i, weighted_raw: raw.to_i, probability_sum: probabilities.to_i)
    end
  end

  # Count, value, weighted value and average probability (nil without deals)
  def sum(rows)
    count = rows.sum { |g| g[:count] }
    { count: count, total_cents: rows.sum { |g| g[:total_cents] }, weighted_cents: rows.sum { |g| g[:weighted_raw] } / 100,
      average_probability: count.zero? ? nil : (rows.sum { |g| g[:probability_sum] }.to_f / count).round(1) }
  end

  # The team view's row per employee (nil otherwise), biggest value first
  def assignee_rows(rows, cell = {})
    return nil unless team_view?

    people = names(rows.pluck(:assignee_id))
    result = rows.group_by { |g| g[:assignee_id] }.map do |id, mine|
      sum(mine).merge(assignee_id: id, name: people[id], cell: cell.merge(assignee_cell(id)))
    end
    result.sort_by { |row| -row[:total_cents] }
  end

  # The employees with a target in a month the period touches
  def target_holder_ids
    account.crm_targets.where(period_start: period.month_overlaps.map(&:first)).where('amount_cents > 0').distinct.pluck(:user_id)
  end
end
