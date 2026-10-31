# Custom (MyDesk): edits a deal's fields (not its stage; see Move). Logs amount, assignee and priority changes.
# A stale lock_version raises ActiveRecord::StaleObjectError, which the API turns into 409.
class SalesCrm::Deals::Update < SalesCrm::BaseService
  PERMITTED = %i[title amount contact_id assignee_id close_date description priority lock_version].freeze

  def perform(deal, params)
    params = params.to_h.symbolize_keys.slice(*PERMITTED)
    ActiveRecord::Base.transaction do
      before = { amount_cents: deal.amount_cents, assignee_id: deal.assignee_id, priority: deal.priority }
      assign(deal, params)
      deal.save!
      log_changes(deal, before)
      broadcast('crm.deal_updated', id: deal.id, stage_id: deal.stage_id, pipeline_id: deal.pipeline_id)
      deal
    end
  end

  private

  def assign(deal, params)
    deal.lock_version = params[:lock_version].to_i if params.key?(:lock_version)
    deal.title = params[:title].to_s.strip if params.key?(:title)
    deal.amount_cents = cents_from(params[:amount]) || 0 if params.key?(:amount)
    assign_details(deal, params)
    assign_people(deal, params)
  end

  def assign_details(deal, params)
    deal.close_date = params[:close_date].presence if params.key?(:close_date)
    deal.description = params[:description] if params.key?(:description)
    deal.priority = priority_from(params[:priority]) if params[:priority].present?
  end

  def assign_people(deal, params)
    deal.contact = params[:contact_id].present? ? account.contacts.find(params[:contact_id]) : nil if params.key?(:contact_id)
    deal.assignee = params[:assignee_id].present? ? account.users.find(params[:assignee_id]) : nil if params.key?(:assignee_id)
  end

  def log_changes(deal, before)
    log(deal, 'amount_changed', from: before[:amount_cents], to: deal.amount_cents) if before[:amount_cents] != deal.amount_cents
    log(deal, 'assignee_changed', from: before[:assignee_id], to: deal.assignee_id) if before[:assignee_id] != deal.assignee_id
    log(deal, 'priority_changed', from: before[:priority], to: deal.priority) if before[:priority] != deal.priority
  end
end
