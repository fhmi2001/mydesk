# Custom (MyDesk): monthly sales targets (?month=YYYY-MM). Administrators read every employee's target and the team
# total, and set them; anyone else reads only their own (docs/reports/gap-analysis.md, decision ب).
class Api::V1::Accounts::Crm::TargetsController < Api::V1::Accounts::Crm::BaseController
  before_action :check_admin, only: [:update]

  def show
    render json: targets_json(params[:month].presence || Date.current.strftime('%Y-%m'))
  end

  # amounts: { user_id => amount }; a blank amount clears that employee's target for the month
  def update
    service(SalesCrm::Targets::Set).perform(month: params.require(:month), amounts: params.require(:amounts).to_unsafe_h)
    render json: targets_json(params[:month])
  end

  private

  def admin?
    Current.account_user&.administrator?
  end

  def check_admin
    raise Pundit::NotAuthorizedError unless admin?
  end

  def targets_json(month)
    range = SalesCrm::Target.month_range(month)
    scope = Current.account.crm_targets.where(period_start: range.begin)
    scope = scope.where(user_id: Current.user.id) unless admin?
    json = { month: range.begin.strftime('%Y-%m'), currency: Current.account.crm_currency,
             targets: scope.map { |t| { user_id: t.user_id, amount_cents: t.amount_cents } } }
    json[:team_cents] = scope.sum(:amount_cents) if admin?
    json
  rescue Date::Error
    raise SalesCrm::ValidationError, I18n.t('sales_crm.errors.invalid_month')
  end
end
