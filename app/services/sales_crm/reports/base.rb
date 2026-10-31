# Custom (MyDesk): shared filters for sales reports. Dates are days in the account's time zone. Every report reads its
# deals through SalesCrm::Visibility: team numbers are for administrators, and an employee always gets their own
# deals, whatever assignee they ask for.
class SalesCrm::Reports::Base < SalesCrm::BaseService
  SECONDS_PER_DAY = 86_400

  attr_reader :from, :to, :pipeline, :assignee_id, :range

  # filters: from, to (YYYY-MM-DD), pipeline_id, assignee_id
  def initialize(account:, user:, **filters)
    super(account: account, user: user)
    zone = SalesCrm::TimeZone.for(account)
    @from = zone.parse(filters[:from].to_s)&.beginning_of_day || zone.now.beginning_of_month
    @to = zone.parse(filters[:to].to_s)&.end_of_day || zone.now.end_of_day
    @range = @from..@to
    @pipeline = filters[:pipeline_id].present? ? account.crm_pipelines.find(filters[:pipeline_id]) : nil
    @assignee_id = admin? ? filters[:assignee_id].presence : user.id
  end

  # The same-length window just before `from`, for comparisons
  def previous_range
    length = to - from
    (from - length - 1.second)..(from - 1.second)
  end

  private

  def admin?
    SalesCrm::Visibility.admin?(account, user)
  end

  def deals
    relation = SalesCrm::Visibility.deals(account, user)
    relation = relation.where(pipeline_id: pipeline.id) if pipeline
    relation = relation.where(assignee_id: assignee_id) if assignee_id
    relation
  end

  def currency
    pipeline&.currency || account.crm_pipelines.first&.currency || 'SAR'
  end

  def win_rate(won_count, lost_count)
    closed = won_count + lost_count
    closed.zero? ? 0.0 : (won_count * 100.0 / closed).round(1)
  end

  def average_days_to_close(won_relation)
    seconds = won_relation.pick(Arel.sql('AVG(EXTRACT(EPOCH FROM (won_at - crm_deals.created_at)))'))
    seconds ? (seconds.to_f / SECONDS_PER_DAY).round(1) : 0.0
  end
end
