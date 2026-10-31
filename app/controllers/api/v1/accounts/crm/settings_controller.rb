# Custom (MyDesk): account-level CRM settings (administrators): who sees which deals, the Sales section's one currency
# (changeable only while there are no deals), and the report thresholds (stale days, pipeline coverage multiple)
class Api::V1::Accounts::Crm::SettingsController < Api::V1::Accounts::Crm::BaseController
  before_action :check_admin

  def show
    render json: settings_json
  end

  def update
    attrs = params.require(:settings).permit(:agents_see_own_deals_only, :default_currency, :stale_days, :coverage_multiple)
    if attrs.key?(:agents_see_own_deals_only)
      Current.account.crm_agents_see_own_deals_only = ActiveModel::Type::Boolean.new.cast(attrs[:agents_see_own_deals_only]) == true
    end
    assign_thresholds(attrs)
    Current.account.save!
    SalesCrm::Currency.change!(Current.account, attrs[:default_currency]) if attrs.key?(:default_currency)
    render json: settings_json
  end

  private

  def check_admin
    raise Pundit::NotAuthorizedError unless Current.account_user&.administrator?
  end

  def assign_thresholds(attrs)
    Current.account.crm_stale_days = whole_number!(attrs[:stale_days], 1..365) if attrs.key?(:stale_days)
    Current.account.crm_coverage_multiple = multiple!(attrs[:coverage_multiple]) if attrs.key?(:coverage_multiple)
  end

  def whole_number!(value, range)
    number = Integer(SalesCrm::Normalize.digits(value.to_s), exception: false)
    raise SalesCrm::ValidationError, I18n.t('sales_crm.errors.invalid_stale_days') unless number && range.cover?(number)

    number
  end

  def multiple!(value)
    number = Float(SalesCrm::Normalize.digits(value.to_s), exception: false)
    raise SalesCrm::ValidationError, I18n.t('sales_crm.errors.invalid_coverage') unless number&.between?(0.5, 20)

    number.round(1)
  end

  def settings_json
    account = Current.account
    { agents_see_own_deals_only: ActiveModel::Type::Boolean.new.cast(account.crm_agents_see_own_deals_only) == true,
      default_currency: account.crm_currency, currencies: SalesCrm::Pipeline::CURRENCIES,
      currency_locked: SalesCrm::Currency.locked?(account),
      stale_days: account.crm_stale_days_value, coverage_multiple: account.crm_coverage_multiple_value }
  end
end
