# Custom (MyDesk): what Super Admin shows about the WhatsApp Web gateway: whether it is reachable and
# trusted, its version, and every number on it with the account and inbox it belongs to. Numbers whose
# inbox was deleted are flagged so they can be removed.
class WhatsappWeb::GatewayOverview
  Number = Data.define(:name, :state, :phone, :profile_name, :messages, :created_at, :inbox) do
    def orphan? = inbox.nil?
  end

  attr_reader :error

  def initialize(client: WhatsappWeb::Client.new)
    @client = client
  end

  def configured? = WhatsappWeb::Config.configured?

  def reachable?
    info.present?
  end

  # The platform may only call the gateway when its host is listed in SAFE_FETCH_TRUSTED_HOSTS
  def trusted?
    uri = URI.parse(WhatsappWeb::Config.api_url)
    uri.host.present? && SafeFetch.trusted_host?(uri)
  rescue URI::InvalidURIError
    false
  end

  def info
    return @info if defined?(@info)

    @info = configured? ? @client.server_info.presence : nil
  rescue WhatsappWeb::Client::Error => e
    @error = e.message
    @info = nil
  end

  def version = info&.dig('version')
  def whatsapp_web_version = info&.dig('whatsappWebVersion')

  def numbers
    @numbers ||= reachable? ? build_numbers(@client.fetch_instances) : []
  rescue WhatsappWeb::Client::Error => e
    @error = e.message
    @numbers = []
  end

  private

  def build_numbers(instances)
    names = instances.pluck('name')
    inboxes = Channel::Api.where(webhook_url: names.map { |name| WhatsappWeb::Config.webhook_url_for(name) })
                          .includes(inbox: :account).to_h { |channel| [channel.webhook_url, channel.inbox] }

    instances.map do |instance|
      Number.new(name: instance['name'], state: instance['connectionStatus'], phone: phone(instance['ownerJid']),
                 profile_name: instance['profileName'], messages: instance.dig('_count', 'Message').to_i,
                 created_at: (Time.zone.parse(instance['createdAt']) if instance['createdAt']),
                 inbox: inboxes[WhatsappWeb::Config.webhook_url_for(instance['name'])])
    end
  end

  def phone(jid)
    digits = jid.to_s.split('@').first
    "+#{digits}" if digits.present?
  end
end
