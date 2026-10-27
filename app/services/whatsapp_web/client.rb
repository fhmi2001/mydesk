# Custom (MyDesk): the few Evolution API calls the WhatsApp Web channel needs. The instance is told which
# existing inbox (by name) to post the number's conversations to.
class WhatsappWeb::Client
  class Error < StandardError; end

  TIMEOUT = 15

  def create_instance(name:, account_id:, token:, inbox_name:)
    request(:post, '/instance/create', body: {
              instanceName: name,
              integration: 'WHATSAPP-BAILEYS',
              qrcode: true,
              groupsIgnore: true,
              chatwootAccountId: account_id.to_s,
              chatwootToken: token,
              chatwootUrl: WhatsappWeb::Config.chatwoot_url,
              chatwootNameInbox: inbox_name,
              # Replies go out as the store, without "Agent name:" on top
              chatwootSignMsg: false,
              chatwootReopenConversation: true,
              chatwootConversationPending: false,
              chatwootImportContacts: false,
              chatwootImportMessages: false,
              chatwootMergeBrazilContacts: false,
              autoCreate: false
            })
  end

  # The gateway's own Chatwoot integration does not pass on delivered / read receipts, so have it post
  # them to the platform (Webhooks::WhatsappWebController) with a per-number secret
  def register_receipts_webhook(name)
    request(:post, "/webhook/set/#{escape(name)}", body: {
              webhook: {
                enabled: true,
                url: WhatsappWeb::Config.receipts_url_for(name),
                headers: { 'X-MyDesk-Token' => WhatsappWeb::Config.receipts_token_for(name) },
                byEvents: false,
                base64: false,
                events: ['MESSAGES_UPDATE']
              }
            })
  end

  # { state: 'open' | 'connecting' | 'close', qr_code: data URI or nil }. Asking for the QR while the
  # gateway is already waiting for a scan returns the current code, so this is safe to poll.
  def connection(name)
    state = request(:get, "/instance/connectionState/#{escape(name)}").dig('instance', 'state')
    return { state: state, qr_code: nil } if state == 'open'

    qr = request(:get, "/instance/connect/#{escape(name)}")
    { state: qr.dig('instance', 'state') || state, qr_code: qr['base64'] }
  end

  def logout(name)
    request(:delete, "/instance/logout/#{escape(name)}")
  end

  def delete_instance(name)
    request(:delete, "/instance/delete/#{escape(name)}")
  end

  private

  def escape(name) = ERB::Util.url_encode(name)

  def request(method, path, body: nil)
    response = HTTParty.send(method, "#{WhatsappWeb::Config.api_url}#{path}",
                             headers: { 'apikey' => WhatsappWeb::Config.api_key, 'Content-Type' => 'application/json' },
                             body: body&.to_json, timeout: TIMEOUT)
    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    raise Error, error_message(parsed, response.code) unless response.success?

    parsed
  rescue HTTParty::Error, SocketError, Timeout::Error, Errno::ECONNREFUSED => e
    raise Error, "WhatsApp gateway unreachable: #{e.message}"
  end

  def error_message(parsed, code)
    message = parsed.dig('response', 'message') || parsed['error'] || "HTTP #{code}"
    Array(message).join(', ')
  end
end
