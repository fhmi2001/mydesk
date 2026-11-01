# Custom (MyDesk): التقرير 7, توقعات المبيعات: how much will close by the end of the period (the whole month unless a range
# is given). The open deals expected to close in it fall in their forecast category: the one the employee picked, else
# the one their probability gives (SalesCrm::Deal#effective_forecast_category, worked out here in SQL). The forecast is
# what is won already plus commit; best case adds best case; omitted deals count in neither. Against the target, per
# employee in the team view.
class SalesCrm::Reports::ForecastCategories < SalesCrm::Reports::Report
  KEY = 'forecast'.freeze
  CATEGORIES = SalesCrm::Deal.forecast_categories.keys.freeze
  CATEGORY_SQL = <<~SQL.squish.freeze
    COALESCE(crm_deals.forecast_category,
      CASE WHEN #{PROBABILITY} >= #{SalesCrm::Deal::COMMIT_FROM} THEN #{SalesCrm::Deal.forecast_categories['commit']}
           WHEN #{PROBABILITY} >= #{SalesCrm::Deal::BEST_CASE_FROM} THEN #{SalesCrm::Deal.forecast_categories['best_case']}
           ELSE #{SalesCrm::Deal.forecast_categories['pipeline']} END)
  SQL

  def self.list_filters = %i[product_id lead_source_id]
  def self.forward? = true

  def build
    groups = grouped(open_closing, category: CATEGORY_SQL, assignee_id: 'crm_deals.assignee_id').map { |g| category_named(g) }
    won = won_by_assignee
    totals = forecast(groups, won.values.sum, target_cents(team_view? ? nil : [assignee_id.to_i]))
    { totals: totals, empty: totals[:won_cents].zero? && groups.empty?, assignees: assignee_forecasts(groups, won) }
  end

  # cell: category (commit, best_case, pipeline, omitted) or status: won; and assignee_id
  def drill_scope(cell)
    relation = if cell[:status].to_s == 'won'
                 won_deals
               else
                 category = CATEGORIES.include?(cell[:category].to_s) ? cell[:category].to_s : 'commit'
                 open_closing.joins(:stage).where("#{CATEGORY_SQL} = ?", SalesCrm::Deal.forecast_categories[category])
               end
    by_assignee(relation, cell)
  end

  private

  def open_closing = deals.open.where(close_date: period.dates)
  def won_deals = deals.won.where(won_at: period.range)

  def target_cents(user_ids) = SalesCrm::Metrics::Target.cents(account, period, user_ids: user_ids)

  def category_named(group)
    group.merge(category: SalesCrm::Deal.forecast_categories.key(group[:category].to_i))
  end

  def won_by_assignee = won_deals.group(:assignee_id).sum(:amount_cents).transform_values(&:to_i)

  # `cell` narrows every number to one employee in their row
  def forecast(groups, won_cents, target, cell = {})
    by_category = CATEGORIES.to_h { |c| [c.to_sym, sum(groups.select { |g| g[:category] == c }).merge(cell: cell.merge(category: c))] }
    expected = won_cents + by_category[:commit][:total_cents]
    best = expected + by_category[:best_case][:total_cents]
    counted = groups.reject { |g| g[:category] == 'omitted' }
    { categories: by_category, won_cents: won_cents, won_cell: cell.merge(status: 'won'), weighted_cents: sum(counted)[:weighted_cents],
      forecast_cents: expected, best_case_cents: best, target_cents: target,
      forecast_attainment: SalesCrm::Metrics::QuotaAttainment.call(won_cents: expected, target_cents: target),
      gap_cents: [target - expected, 0].max, total_cents: best }
  end

  def assignee_forecasts(groups, won)
    return nil unless team_view?

    ids = (groups.pluck(:assignee_id) + won.keys + target_holder_ids).uniq
    people = names(ids)
    rows = ids.map do |id|
      forecast(groups.select { |g| g[:assignee_id] == id }, won.fetch(id, 0), id ? target_cents([id]) : 0, assignee_cell(id))
        .merge(assignee_id: id, name: people[id], cell: assignee_cell(id))
    end
    rows.sort_by { |row| -row[:forecast_cents] }
  end
end
