# Custom (MyDesk): edits a deal's fields (not its stage; see Move). Logs amount, expected close date, assignee and
# priority changes. An open deal leaves the edit with an amount, an expected close date and an owner.
# A stale lock_version raises ActiveRecord::StaleObjectError, which the API turns into 409.
class SalesCrm::Deals::Update < SalesCrm::BaseService
  PERMITTED = (%i[title amount contact_id assignee_id close_date description priority forecast_category probability_override
                  lock_version] + LIST_PARAMS).freeze
  LOGGED = %i[amount_cents close_date assignee_id priority].freeze

  def perform(deal, params)
    params = params.to_h.symbolize_keys.slice(*PERMITTED)
    ActiveRecord::Base.transaction do
      before = LOGGED.index_with { |field| deal.public_send(field) }
      assign(deal, params)
      require_open_essentials!(deal)
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
    assign_forecast(deal, params)
    assign_list_items(deal, params)
    assign_people(deal, params)
  end

  def assign_details(deal, params)
    deal.close_date = params[:close_date].presence if params.key?(:close_date)
    deal.description = params[:description] if params.key?(:description)
    deal.priority = priority_from(params[:priority]) if params[:priority].present?
  end

  # Blank puts the deal back on its stage's probability, and on the category derived from it
  def assign_forecast(deal, params)
    deal.forecast_category = forecast_category_from(params[:forecast_category]) if params.key?(:forecast_category)
    deal.probability_override = probability_from(params[:probability_override]) if params.key?(:probability_override)
  end

  def assign_people(deal, params)
    deal.contact = params[:contact_id].present? ? account.contacts.find(params[:contact_id]) : nil if params.key?(:contact_id)
    deal.assignee = params[:assignee_id].present? ? account.users.find(params[:assignee_id]) : nil if params.key?(:assignee_id)
  end

  def log_changes(deal, before)
    log(deal, 'amount_changed', from: before[:amount_cents], to: deal.amount_cents) if before[:amount_cents] != deal.amount_cents
    log(deal, 'close_date_changed', from: before[:close_date]&.iso8601, to: deal.close_date&.iso8601) if before[:close_date] != deal.close_date
    log(deal, 'assignee_changed', from: before[:assignee_id], to: deal.assignee_id) if before[:assignee_id] != deal.assignee_id
    log(deal, 'priority_changed', from: before[:priority], to: deal.priority) if before[:priority] != deal.priority
  end
end
