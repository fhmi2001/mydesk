# Custom (MyDesk): التقرير 16, جودة البيانات: which open deals are missing something or out of date, so they spoil the
# other reports. Complete (المؤشر 10, SalesCrm::Metrics::DataCompleteness): an amount, an expected close date and an
# owner. Beyond that the report flags a close date already past and no activity for the account's stale days. Each
# listed deal says what it lacks; an employee sees their own to fix them. A picture of now.
class SalesCrm::Reports::DataQuality < SalesCrm::Reports::Report
  KEY = 'data_quality'.freeze
  ISSUES = %w[no_amount no_close_date past_close_date no_owner stale].freeze

  def self.list_filters = %i[product_id lead_source_id]
  def self.stage_filter? = true

  def initialize(account:, user:, **filters)
    super
    @today = today
  end

  def build
    completeness = SalesCrm::Metrics::DataCompleteness.call(deals)
    counts = ISSUES.index_with { |issue| issue_scope(issue).count }
    { stale_days: account.crm_stale_days_value, totals: completeness.merge(issues: counts, to_fix: any_issue.count),
      empty: completeness[:open_count].zero?, rows: lines(any_issue, { amount_cents: :desc, id: :asc }).map { |line| with_issues(line) },
      assignees: assignee_figures }
  end

  # cell: issue (one of ISSUES; any of them when absent) and assignee_id
  def drill_scope(cell)
    by_assignee(ISSUES.include?(cell[:issue].to_s) ? issue_scope(cell[:issue].to_s) : any_issue, cell)
  end

  def drill(page: 1)
    result = super
    result.merge(items: result[:items].map { |line| with_issues(line) })
  end

  private

  def condition(issue)
    { 'no_amount' => ['crm_deals.amount_cents <= 0'],
      'no_close_date' => ['crm_deals.close_date IS NULL'],
      'past_close_date' => ['crm_deals.close_date < ?', @today],
      'no_owner' => ['crm_deals.assignee_id IS NULL'] }.fetch(issue)
  end

  # Stale is the shared condition of Metrics::DaysSinceActivity (the report 3 counts the same deals)
  def issue_scope(issue)
    return SalesCrm::Metrics::DaysSinceActivity.stale(deals, account.crm_stale_days_value, zone: zone, today: @today) if issue == 'stale'

    deals.open.where(*condition(issue))
  end

  def any_issue
    ISSUES.map { |issue| issue_scope(issue) }.reduce(:or)
  end

  # What a listed deal lacks
  def with_issues(line)
    issues = []
    issues << 'no_amount' unless line[:amount_cents].positive?
    issues << 'no_close_date' if line[:close_date].nil?
    issues << 'past_close_date' if line[:days_overdue]
    issues << 'no_owner' if line[:assignee].nil?
    issues << 'stale' if line[:days_since_activity] >= account.crm_stale_days_value
    line.merge(issues: issues)
  end

  def assignee_figures
    return nil unless team_view?

    open_by = deals.open.group(:assignee_id).count
    complete_by = complete_by_assignee
    fix_by = any_issue.group(:assignee_id).count
    people = names(open_by.keys)
    rows = open_by.map do |id, open_count|
      { assignee_id: id, name: people[id], open_count: open_count, to_fix: fix_by.fetch(id, 0),
        rate: SalesCrm::Metrics::Ratio.percent(complete_by.fetch(id, 0), open_count), cell: assignee_cell(id) }
    end
    rows.sort_by { |row| -row[:to_fix] }
  end

  def complete_by_assignee
    deals.open.where(Arel.sql(SalesCrm::Metrics::DataCompleteness::COMPLETE_SQL)).group(:assignee_id).count
  end
end
