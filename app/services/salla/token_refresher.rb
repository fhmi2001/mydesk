# Custom (MyDesk): Salla access tokens last 14 days. A daily job renews those close to expiring;
# a hook whose refresh fails is disabled so the merchant is asked to connect again.
class Salla::TokenRefresher
  REFRESH_WINDOW = 3.days

  pattr_initialize [:hook!]

  def self.due_hooks
    Integrations::Hook.where(app_id: 'salla', status: :enabled).select do |hook|
      expires_at = Time.zone.parse(hook.settings['expires_at'].to_s) if hook.settings['expires_at'].present?
      expires_at.nil? || expires_at < REFRESH_WINDOW.from_now
    end
  end

  def perform
    tokens = Salla::OauthClient.new.refresh(hook.settings['refresh_token'])
    hook.update!(access_token: tokens['access_token'], settings: hook.settings.merge(Salla::ConnectService.token_settings(tokens)))
  rescue Salla::OauthClient::Error => e
    Rails.logger.error("[Salla] Token refresh failed for account #{hook.account_id}: #{e.message}")
    hook.update!(status: :disabled, settings: hook.settings.merge('disabled_reason' => 'token_refresh_failed'))
  end
end
