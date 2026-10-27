# Custom (MyDesk): delivery / read receipts from the WhatsApp Web gateway. Each number posts with its own
# secret in X-MyDesk-Token (WhatsappWeb::Config.receipts_token_for).
class Webhooks::WhatsappWebController < ActionController::API
  before_action :verify_token!

  def receipts
    inbox = WhatsappWeb::Config.inbox_for(params[:instance])
    WhatsappWeb::ReceiptProcessor.new(inbox: inbox, payload: payload).perform if inbox
    head :ok
  end

  private

  def payload
    JSON.parse(request.raw_post.to_s)
  rescue JSON::ParserError
    {}
  end

  def verify_token!
    expected = WhatsappWeb::Config.receipts_token_for(params[:instance].to_s)
    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(request.headers['X-MyDesk-Token'].to_s, expected)
  end
end
