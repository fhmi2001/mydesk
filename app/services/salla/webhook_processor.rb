# Custom (MyDesk): routes one Salla webhook to the account whose store sent it.
# App events keep the connection in step; order events are logged as SallaEvent rows for later notifications.
class Salla::WebhookProcessor
  pattr_initialize [:payload!]

  def perform
    return if hook.blank?

    case event
    when 'app.uninstalled' then hook.destroy!
    when 'app.store.authorize' then store_new_tokens
    else log_event if event.start_with?('order.')
    end
  end

  private

  def event = payload['event'].to_s
  def data = payload['data'] || {}

  # Events of stores that are not connected to MyDesk are ignored
  def hook
    @hook ||= Integrations::Hook.find_by(app_id: 'salla', reference_id: payload['merchant'].to_s) if payload['merchant'].present?
  end

  def store_new_tokens
    tokens = { 'access_token' => data['access_token'], 'refresh_token' => data['refresh_token'],
               'expires_in' => data['expires'].to_i - Time.current.to_i, 'scope' => data['scope'] }
    hook.update!(access_token: tokens['access_token'], status: :enabled,
                 settings: hook.settings.merge(Salla::ConnectService.token_settings(tokens)))
  end

  # Order payloads carry the order either at the top of data or under data.order (status updates)
  def log_event
    SallaEvent.create!(account_id: hook.account_id, hook_id: hook.id, merchant_id: hook.reference_id, event: event,
                       payload: payload, **order_attributes)
  end

  def order_attributes
    order = data['order'].is_a?(Hash) ? data['order'] : data
    customer = order['customer'] || {}
    {
      order_id: order['id']&.to_s,
      order_reference: order['reference_id']&.to_s,
      status_name: status_name(order),
      customer_name: customer.values_at('first_name', 'last_name').compact.join(' ').presence,
      customer_mobile: customer.values_at('mobile_code', 'mobile').compact.join.presence
    }
  end

  def status_name(order)
    status = data['status'].presence || order['status']
    status.is_a?(Hash) ? status['name'] : status
  end
end
