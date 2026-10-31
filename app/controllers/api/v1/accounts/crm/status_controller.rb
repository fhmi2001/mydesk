# Custom (MyDesk): what the sidebar needs: is the CRM on, how many of my tasks are overdue, am I an admin
class Api::V1::Accounts::Crm::StatusController < Api::V1::Accounts::Crm::BaseController
  skip_before_action :ensure_crm_enabled

  def show
    unless crm_enabled?
      render json: { enabled: false }
      return
    end

    SalesCrm::Pipelines::EnsureDefault.call(Current.account)
    render json: {
      enabled: true,
      is_admin: Current.account_user&.administrator? || false,
      overdue_count: service(SalesCrm::Tasks::List).overdue_count(tasks_scope),
      settings: {
        agents_see_own_deals_only: ActiveModel::Type::Boolean.new.cast(Current.account.crm_agents_see_own_deals_only) == true,
        default_currency: Current.account.crm_default_currency.presence || 'SAR',
        timezone: SalesCrm::TimeZone.for(Current.account).tzinfo.name
      }
    }
  end
end
