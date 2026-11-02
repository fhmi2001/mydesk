# Custom (MyDesk): shared filters for sales reports. The period is whole days in the account's time zone (SalesCrm::Period); the
# numbers come from the metric units in SalesCrm::Metrics, so no metric is worked out two ways. Every report reads its
# deals through SalesCrm::Visibility: team numbers are for administrators, and an employee always gets their own
# deals, whatever assignee they ask for.
class SalesCrm::Reports::Base < SalesCrm::BaseService
  attr_reader :period, :pipeline, :assignee_id

  # filters: from, to (YYYY-MM-DD), pipeline_id, assignee_id
  def initialize(account:, user:, **filters)
    super(account: account, user: user)
    @period = SalesCrm::Period.parse(filters[:from], filters[:to], zone: zone)
    @pipeline = filters[:pipeline_id].present? ? account.crm_pipelines.find(filters[:pipeline_id]) : nil
    @assignee_id = admin? ? filters[:assignee_id].presence : user.id
  end

  def from = period.begins_at
  def to = period.ends_at
  def range = period.range

  # Custom (MyDesk): the account's time zone (general settings), Riyadh until it picks one
  def zone = @zone ||= SalesCrm::TimeZone.for(account)
  def today = SalesCrm::Period.today(zone)

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
    account.crm_currency
  end
end
