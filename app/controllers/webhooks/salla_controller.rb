# Custom (MyDesk): receives the webhooks of every connected Salla store (https://docs.salla.dev/webhooks).
# Requests are signed: X-Salla-Signature is the HMAC-SHA256 of the raw body with the app's webhook secret.
class Webhooks::SallaController < ActionController::API
  before_action :verify_signature!

  def events
    Salla::WebhookProcessor.new(payload: payload).perform
    head :ok
  end

  private

  def payload
    @payload ||= JSON.parse(raw_body)
  rescue JSON::ParserError
    {}
  end

  def raw_body
    @raw_body ||= request.raw_post.to_s
  end

  def verify_signature!
    secret = Salla::Config.webhook_secret
    signature = request.headers['X-Salla-Signature'].to_s
    expected = OpenSSL::HMAC.hexdigest('SHA256', secret.to_s, raw_body)
    head :unauthorized if secret.blank? || !ActiveSupport::SecurityUtils.secure_compare(signature, expected)
  end
end
