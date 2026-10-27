# Custom (MyDesk): turns an approved Salla authorization into the account's Salla integration hook.
# reference_id holds the Salla merchant id, which is how webhooks find the account.
class Salla::ConnectService
  class StoreTakenError < StandardError; end

  pattr_initialize [:account!, :code!]

  def perform
    tokens = client.exchange_code(code)
    merchant = client.user_info(tokens['access_token'])['merchant'] || {}
    merchant_id = merchant['id'].to_s
    raise Salla::OauthClient::Error, 'Salla did not return the store' if merchant_id.blank?
    raise StoreTakenError, 'This Salla store is already connected to another account' if taken_elsewhere?(merchant_id)

    save_hook(merchant_id, merchant, tokens)
  end

  def self.token_settings(tokens)
    {
      'refresh_token' => tokens['refresh_token'],
      'expires_at' => (Time.current + tokens['expires_in'].to_i.seconds).iso8601,
      'scope' => tokens['scope']
    }
  end

  private

  def client
    @client ||= Salla::OauthClient.new
  end

  def taken_elsewhere?(merchant_id)
    Integrations::Hook.where(app_id: 'salla', reference_id: merchant_id).where.not(account_id: account.id).exists?
  end

  def save_hook(merchant_id, merchant, tokens)
    hook = account.hooks.find_or_initialize_by(app_id: 'salla')
    hook.assign_attributes(
      reference_id: merchant_id,
      access_token: tokens['access_token'],
      status: :enabled,
      settings: self.class.token_settings(tokens).merge(
        'store_name' => merchant['name'],
        'store_username' => merchant['username'],
        'store_domain' => merchant['domain'],
        'store_avatar' => merchant['avatar'],
        'connected_at' => Time.current.iso8601
      )
    )
    hook.save!
    hook
  end
end
