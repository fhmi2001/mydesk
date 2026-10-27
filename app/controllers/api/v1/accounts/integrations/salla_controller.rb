# Custom (MyDesk): connect / disconnect the account's Salla store and list the latest events it sent
class Api::V1::Accounts::Integrations::SallaController < Api::V1::Accounts::Integrations::BaseController
  EVENTS_LIMIT = 50

  before_action :check_authorization
  before_action :ensure_configured, only: [:auth]

  def auth
    render json: { redirect_url: Salla::OauthClient.authorize_url(Current.account.id) }
  end

  def events
    events = Current.account.salla_events.latest.limit(EVENTS_LIMIT)
    render json: {
      payload: events.map do |event|
        event.slice(:id, :event, :order_id, :order_reference, :status_name, :customer_name, :customer_mobile)
             .merge(created_at: event.created_at.to_i)
      end
    }
  end

  def destroy
    Current.account.hooks.where(app_id: 'salla').destroy_all
    head :ok
  end

  private

  # Every Salla action is admin-only, like managing any other integration hook
  def check_authorization
    authorize(:hook, :create?)
  end

  def ensure_configured
    render json: { error: 'Salla is not configured' }, status: :unprocessable_entity unless Salla::Config.configured?
  end
end
