# Custom (MyDesk): the MyDesk app registered on Salla Partners. Its keys are set from Super Admin > Salla
# (or the SALLA_* environment variables) and are shared by every account that connects a store.
module Salla::Config
  AUTHORIZE_URL = 'https://accounts.salla.sa/oauth2/auth'.freeze
  TOKEN_URL = 'https://accounts.salla.sa/oauth2/token'.freeze
  USER_INFO_URL = 'https://accounts.salla.sa/oauth2/user/info'.freeze
  API_URL = 'https://api.salla.dev/admin/v2'.freeze
  # offline_access returns a refresh token, so the connection survives the 14-day access token
  SCOPES = 'offline_access'.freeze

  module_function

  def client_id = GlobalConfigService.load('SALLA_CLIENT_ID', nil)
  def client_secret = GlobalConfigService.load('SALLA_CLIENT_SECRET', nil)
  def webhook_secret = GlobalConfigService.load('SALLA_WEBHOOK_SECRET', nil)

  def configured?
    client_id.present? && client_secret.present?
  end

  def redirect_uri
    "#{ENV.fetch('FRONTEND_URL', '')}/salla/callback"
  end

  def integration_url(account_id, **query)
    url = "#{ENV.fetch('FRONTEND_URL', '')}/app/accounts/#{account_id}/settings/integrations/salla"
    query.present? ? "#{url}?#{query.to_query}" : url
  end
end
