# Custom (MyDesk): account-level CRM settings (administrators)
class Api::V1::Accounts::Crm::SettingsController < Api::V1::Accounts::Crm::BaseController
  before_action :check_admin

  def show
    render json: settings_json
  end

  def update
    attrs = params.require(:settings).permit(:agents_see_own_deals_only, :default_currency)
    if attrs.key?(:agents_see_own_deals_only)
      Current.account.crm_agents_see_own_deals_only = ActiveModel::Type::Boolean.new.cast(attrs[:agents_see_own_deals_only]) == true
    end
    if attrs.key?(:default_currency)
      currency = attrs[:default_currency].to_s.upcase
      raise SalesCrm::ValidationError, I18n.t('sales_crm.errors.invalid_currency') unless SalesCrm::Pipeline::CURRENCIES.include?(currency)

      Current.account.crm_default_currency = currency
    end
    Current.account.save!
    render json: settings_json
  end

  private

  def check_admin
    raise Pundit::NotAuthorizedError unless Current.account_user&.administrator?
  end

  def settings_json
    { agents_see_own_deals_only: ActiveModel::Type::Boolean.new.cast(Current.account.crm_agents_see_own_deals_only) == true,
      default_currency: Current.account.crm_default_currency.presence || 'SAR', currencies: SalesCrm::Pipeline::CURRENCIES }
  end
end
