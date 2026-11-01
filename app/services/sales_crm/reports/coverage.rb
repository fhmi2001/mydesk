# Custom (MyDesk): التقرير 8, تغطية خط الأنابيب: is the open value expected to close in the period enough for what is left
# of the target (المؤشر 3)? Rated against the account's coverage multiple (3 unless changed in Sales settings): at or
# above it good, at least once what is left a warning, below that bad. The period is the whole month unless a range is
# given; targets are per employee and month, so like Reports::Quota this report takes no pipeline.
class SalesCrm::Reports::Coverage < SalesCrm::Reports::Report
  KEY = 'coverage'.freeze

  def self.forward? = true

  def initialize(account:, user:, **filters)
    super(account: account, user: user, **filters.except(:pipeline_id))
  end

  def build
    totals = figures(deals, target_user_ids)
    { multiple: multiple, totals: totals, empty: totals[:target_cents].zero? && totals[:open_cents].zero?, assignees: rows }
  end

  # cell: status (open, the default, or won) and assignee_id
  def drill_scope(cell)
    by_assignee(cell[:status].to_s == 'won' ? won : open_closing, cell)
  end

  private

  def drill_order = { close_date: :asc, amount_cents: :desc, id: :asc }

  def open_closing(relation = deals) = relation.open.where(close_date: period.dates)
  def won(relation = deals) = relation.won.where(won_at: period.range)
  def multiple = account.crm_coverage_multiple_value

  def target_user_ids = team_view? ? nil : [assignee_id.to_i]

  def figures(relation, user_ids)
    open_cents = SalesCrm::Metrics::PipelineCoverage.open_closing_cents(relation, period)
    won_cents = won(relation).sum(:amount_cents)
    target = SalesCrm::Metrics::Target.cents(account, period, user_ids: user_ids)
    coverage = SalesCrm::Metrics::PipelineCoverage.call(open_cents: open_cents, target_cents: target, won_cents: won_cents)
    { open_cents: open_cents, open_count: open_closing(relation).count, won_cents: won_cents, target_cents: target,
      remaining_cents: [target - won_cents, 0].max, coverage: coverage, rating: rating(coverage) }
  end

  # good / warn / bad against the multiple; nil when nothing is left to cover
  def rating(coverage)
    return nil if coverage.nil?
    return 'good' if coverage >= multiple
    return 'warn' if coverage >= 1

    'bad'
  end

  def rows
    return nil unless team_view?

    ids = (target_holder_ids + open_closing.distinct.pluck(:assignee_id) + won.distinct.pluck(:assignee_id)).uniq
    people = names(ids)
    result = ids.map do |id|
      figures(deals.where(assignee_id: id), [id]).merge(assignee_id: id, name: people[id], cell: assignee_cell(id))
    end
    result.sort_by { |row| [row[:coverage] ? 0 : 1, row[:coverage].to_f] }
  end
end
