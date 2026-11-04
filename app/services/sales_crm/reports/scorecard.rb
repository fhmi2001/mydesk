# Custom (MyDesk): التقرير 19, بطاقة أداء الموظف: how each employee does against the team, for the one-to-one. One card per
# employee: attainment, win rate, coverage, sales cycle, average won deal, activity (tasks completed and notes, as in
# Reports::Activity), new deals and data completeness, each from its metric unit. The manager gets every active
# employee (with a target or a deal in the period) and the team average over them; with an
# employee picked, that card beside the average. An employee gets their own card only: the average is built from
# colleagues' numbers. The period is the whole month unless a range is given; targets are not per pipeline.
class SalesCrm::Reports::Scorecard < SalesCrm::Reports::Report
  KEY = 'scorecard'.freeze
  METRICS = %i[attainment won_cents target_cents win_rate coverage sales_cycle average_deal_cents activity_count
               new_deal_count completeness].freeze
  STATUSES = %w[won open new].freeze

  def self.forward? = true

  def initialize(account:, user:, **filters)
    super(account: account, user: user, **filters.except(:pipeline_id))
  end

  def build
    return own_card unless admin?

    cards = active_ids.map { |id| card(id) }
    shown = assignee_id ? [picked(cards)] : cards
    { cards: shown.sort_by { |c| -(c[:attainment] || -1) }, team_average: average(cards), team_size: cards.size,
      empty: shown.all? { |c| c[:empty] } }
  end

  # cell: status (won, open: closing in the period, new: created in it) and assignee_id
  def drill_scope(cell)
    relation = case cell[:status].to_s
               when 'open' then deals.open.where(close_date: period.dates)
               when 'new' then deals.where(created_at: period.range)
               else deals.won.where(won_at: period.range)
               end
    by_assignee(relation, cell)
  end

  private

  def team_view? = admin? && assignee_id.nil?

  def picked(cards) = cards.find { |c| c[:assignee_id] == assignee_id.to_i } || card(assignee_id.to_i)

  def own_card
    mine = card(user.id)
    { cards: [mine], team_average: nil, team_size: nil, empty: mine[:empty] }
  end

  def everyone = SalesCrm::Visibility.deals(account, user)

  # Employees with a target in the period, or a deal closed, expected or created in it
  def active_ids
    (target_holder_ids + in_period.distinct.pluck(:assignee_id)).compact.uniq
  end

  def in_period
    closed = everyone.where(won_at: period.range).or(everyone.where(lost_at: period.range))
    closed.or(everyone.open.where(close_date: period.dates)).or(everyone.where(created_at: period.range))
  end

  def card(id)
    mine = everyone.where(assignee_id: id)
    won = SalesCrm::Metrics::WinRate.call(mine, period)
    target = SalesCrm::Metrics::Target.cents(account, period, user_ids: [id])
    open_cents = SalesCrm::Metrics::PipelineCoverage.open_closing_cents(mine, period)
    figures = target_figures(won, target, open_cents).merge(deal_figures(mine, id))
    figures.merge(assignee_id: id, name: names([id])[id], open_cents: open_cents, cell: assignee_cell(id),
                  empty: target.zero? && won[:won_count].zero? && open_cents.zero? && figures[:new_deal_count].zero?)
  end

  def deal_figures(mine, id)
    { sales_cycle: SalesCrm::Metrics::SalesCycle.call(mine, period), average_deal_cents: SalesCrm::Metrics::AverageDealSize.call(mine, period),
      activity_count: activity_count(id), new_deal_count: mine.where(created_at: period.range).count,
      completeness: SalesCrm::Metrics::DataCompleteness.call(mine)[:rate] }
  end

  def target_figures(won, target, open_cents)
    { attainment: SalesCrm::Metrics::QuotaAttainment.call(won_cents: won[:won_cents], target_cents: target),
      won_cents: won[:won_cents], target_cents: target, win_rate: won[:by_count],
      coverage: SalesCrm::Metrics::PipelineCoverage.call(open_cents: open_cents, target_cents: target, won_cents: won[:won_cents]) }
  end

  def activity_count(id)
    account.crm_tasks.done.where(assignee_id: id, done_at: period.range).count +
      account.crm_notes.where(user_id: id, created_at: period.range).count
  end

  # Each metric's mean over the cards that have it (a rate with nothing to divide is left out, not counted as 0)
  def average(cards)
    METRICS.index_with do |metric|
      values = cards.filter_map { |c| c[metric] }
      next nil if values.empty?

      mean = values.sum.to_f / values.size
      metric.to_s.end_with?('cents') ? mean.round : mean.round(1)
    end
  end
end
