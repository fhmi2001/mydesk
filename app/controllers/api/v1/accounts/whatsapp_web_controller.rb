# Custom (MyDesk): the WhatsApp Web (QR) channel. Creates the inbox and its number on the gateway, then
# serves the QR code and connection state so the admin can link the phone in-app.
class Api::V1::Accounts::WhatsappWebController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :ensure_configured, except: [:show]
  before_action :fetch_inbox, only: [:connection, :logout]

  rescue_from WhatsappWeb::Client::Error do |error|
    render json: { error: error.message }, status: :bad_gateway
  end

  def show
    render json: { configured: WhatsappWeb::Config.configured? }
  end

  # The inbox is created here rather than left to the gateway, which adds it only seconds after replying.
  # The gateway finds it by name, so names must be unique in the account.
  def create
    inbox_name = params.require(:name).to_s.strip
    if Current.account.inboxes.exists?(name: inbox_name)
      return render json: { error: 'An inbox with this name already exists', code: 'name_taken' }, status: :unprocessable_entity
    end

    instance_name = "mydesk-#{Current.account.id}-#{SecureRandom.hex(4)}"
    inbox = create_inbox(inbox_name, instance_name)
    begin
      client.create_instance(name: instance_name, account_id: Current.account.id, token: Current.user.access_token.token,
                             inbox_name: inbox_name)
    rescue WhatsappWeb::Client::Error
      inbox.destroy!
      raise
    end

    render json: { id: inbox.id, name: inbox.name }
  end

  def connection
    render json: client.connection(@instance_name)
  end

  def logout
    client.logout(@instance_name)
    head :ok
  end

  private

  # Adding a channel is an admin action, like creating any inbox
  def check_authorization
    authorize(::Inbox, :create?)
  end

  def ensure_configured
    render json: { error: 'WhatsApp Web is not configured' }, status: :unprocessable_entity unless WhatsappWeb::Config.configured?
  end

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    @instance_name = WhatsappWeb::Config.instance_name_for(@inbox)
    render json: { error: 'Not a WhatsApp Web inbox' }, status: :unprocessable_entity unless @instance_name
  end

  def create_inbox(inbox_name, instance_name)
    ActiveRecord::Base.transaction do
      channel = Channel::Api.create!(account: Current.account, webhook_url: WhatsappWeb::Config.webhook_url_for(instance_name))
      Current.account.inboxes.create!(name: inbox_name, channel: channel)
    end
  end

  def client
    @client ||= WhatsappWeb::Client.new
  end
end
