# Custom (MyDesk): the WhatsApp Web (QR) gateway, an Evolution API server running beside the platform
# (see deploy/whatsapp). Set from Super Admin > WhatsApp Web, or the WHATSAPP_WEB_* environment variables.
module WhatsappWeb::Config
  # Evolution points each inbox's webhook at <gateway>/chatwoot/webhook/<instance name>
  WEBHOOK_PATH = %r{/chatwoot/webhook/(?<instance>[^/?#]+)\z}

  module_function

  # How the platform reaches the gateway, e.g. http://evolution-api:8080
  def api_url = GlobalConfigService.load('WHATSAPP_WEB_API_URL', nil).to_s.chomp('/')
  def api_key = GlobalConfigService.load('WHATSAPP_WEB_API_KEY', nil)

  # How the gateway reaches the platform's API; defaults to the public URL
  def chatwoot_url
    GlobalConfigService.load('WHATSAPP_WEB_CHATWOOT_URL', nil).presence || ENV.fetch('FRONTEND_URL', '')
  end

  def configured?
    api_url.present? && api_key.present?
  end

  # Where the platform sends agent replies for a number; the gateway uses the same path
  def webhook_url_for(instance_name)
    "#{api_url}/chatwoot/webhook/#{ERB::Util.url_encode(instance_name)}"
  end

  # Where the gateway posts delivery / read receipts for a number, and the secret it sends along
  def receipts_url_for(instance_name)
    "#{chatwoot_url.to_s.chomp('/')}/webhooks/whatsapp_web/#{ERB::Util.url_encode(instance_name)}"
  end

  def receipts_token_for(instance_name)
    OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secret_key_base, "whatsapp_web:receipts:#{instance_name}")
  end

  def inbox_for(instance_name)
    channel = Channel::Api.find_by(webhook_url: webhook_url_for(instance_name))
    channel&.inbox
  end

  def instance_name_for(inbox)
    return unless inbox&.channel_type == 'Channel::Api'

    inbox.channel.webhook_url.to_s[WEBHOOK_PATH, :instance]
  end
end
