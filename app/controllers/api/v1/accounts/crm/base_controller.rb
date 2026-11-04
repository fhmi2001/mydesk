# Custom (MyDesk): shared behaviour of the Sales CRM API: the account must have the feature switched on, and
# the CRM's own errors become the agreed HTTP answers (422 message, 409 stale, 403 disabled). A record that fails its
# own validations answers in the same 422 shape as a SalesCrm::ValidationError, whichever service raised it.
class Api::V1::Accounts::Crm::BaseController < Api::V1::Accounts::BaseController
  before_action :ensure_crm_enabled

  rescue_from ActiveRecord::RecordInvalid, with: :render_crm_record_invalid
  rescue_from SalesCrm::ValidationError, with: :render_crm_validation_error
  rescue_from ActiveRecord::StaleObjectError, with: :render_stale

  private

  def ensure_crm_enabled
    return if crm_enabled?

    render json: { error: 'crm_disabled' }, status: :forbidden
  end

  def crm_enabled?
    Current.account.feature_enabled?('sales_crm')
  end

  def render_crm_validation_error(exception)
    render json: { message: exception.message }, status: :unprocessable_entity
  end

  def render_crm_record_invalid(exception)
    render json: { message: exception.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def render_stale(_exception)
    render json: { error: 'stale' }, status: :conflict
  end

  def deals_scope
    SalesCrm::DealPolicy::Scope.new(pundit_user, SalesCrm::Deal).resolve
  end

  def tasks_scope
    SalesCrm::TaskPolicy::Scope.new(pundit_user, SalesCrm::Task).resolve
  end

  def service(klass)
    klass.new(account: Current.account, user: Current.user)
  end

  def present_deals(deals)
    deals.map { |d| SalesCrm::Presenter.deal(d) }
  end
end
