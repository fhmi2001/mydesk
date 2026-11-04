# Custom (MyDesk): التقرير 6, الإنجاز مقابل الهدف: how much of the target is won and how much is left (المؤشر 2). The
# period is the whole month unless a range is given, since a target is for the month (SalesCrm::Metrics::Target). The
# team view ranks the employees by attainment; the line compares the value won so far, day by day, with the target
# spread evenly over the period. Targets are not per pipeline or product, so this report takes no such filter.
class SalesCrm::Reports::Quota < SalesCrm::Reports::Report
  KEY = 'quota'.freeze

  def self.forward? = true

  def initialize(account:, user:, **filters)
    super(account: account, user: user, **filters.except(:pipeline_id))
  end

  def build
    totals = figures(period, target_user_ids)
    { totals: totals, previous_totals: figures(period.previous, target_user_ids),
      empty: totals[:target_cents].zero? && totals[:won_count].zero?, assignees: ranked, cumulative: cumulative(totals[:target_cents]) }
  end

  def drill_scope(cell) = by_assignee(won(period), cell)

  private

  def drill_order = { won_at: :desc, id: :desc }

  def won(window) = deals.won.where(won_at: window.range)

  # nil: every target in the account (the team); else the employee's own
  def target_user_ids = team_view? ? nil : [assignee_id.to_i]

  def figures(window, user_ids, relation = won(window))
    count, cents = relation.pick(Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(crm_deals.amount_cents), 0)'))
    target = SalesCrm::Metrics::Target.cents(account, window, user_ids: user_ids)
    { won_count: count.to_i, won_cents: cents.to_i, target_cents: target, remaining_cents: [target - cents.to_i, 0].max,
      attainment: SalesCrm::Metrics::QuotaAttainment.call(won_cents: cents.to_i, target_cents: target) }
  end

  # Everyone with a target in the period or a deal won in it, best attainment first (no target: last, by value won)
  def ranked
    return nil unless team_view?

    ids = (target_holder_ids + won(period).distinct.pluck(:assignee_id)).uniq
    people = names(ids)
    rows = ids.map do |id|
      figures(period, [id], won(period).where(assignee_id: id)).merge(assignee_id: id, name: people[id], cell: assignee_cell(id))
    end
    rows.sort_by { |r| rank_key(r) }.each_with_index.map { |r, i| r.merge(rank: i + 1) }
  end

  def rank_key(row) = [row[:attainment] ? 0 : 1, -(row[:attainment] || 0), -row[:won_cents]]

  # [{ date, won_cents (running total; nil after today), target_cents (the target's share of the days so far) }]
  def cumulative(target)
    by_day = won(period).pluck(:won_at, :amount_cents).group_by { |at, _| local_date(at) }
    running = 0
    period.dates.each_with_index.map do |date, index|
      running += by_day.fetch(date, []).sum(&:last)
      { date: date.iso8601, won_cents: date > today ? nil : running, target_cents: (target * (index + 1) / period.days.to_r).round }
    end
  end
end
