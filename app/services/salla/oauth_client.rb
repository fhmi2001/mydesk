# Custom (MyDesk): Salla OAuth 2.0 in Custom Mode (https://docs.salla.dev/doc-421118).
# The merchant approves MyDesk on accounts.salla.sa and comes back to /salla/callback with a code.
class Salla::OauthClient
  class Error < StandardError; end

  STATE_TTL = 15.minutes

  # The state carries the MyDesk account, signed so a callback cannot be pointed at another account
  def self.state_for(account_id)
    JWT.encode({ sub: account_id, exp: STATE_TTL.from_now.to_i }, Salla::Config.client_secret, 'HS256')
  end

  def self.account_id_from(state)
    JWT.decode(state.to_s, Salla::Config.client_secret, true, algorithm: 'HS256').first['sub']
  rescue JWT::DecodeError
    nil
  end

  def self.authorize_url(account_id)
    query = {
      client_id: Salla::Config.client_id,
      response_type: 'code',
      redirect_uri: Salla::Config.redirect_uri,
      scope: Salla::Config::SCOPES,
      state: state_for(account_id)
    }
    "#{Salla::Config::AUTHORIZE_URL}?#{query.to_query}"
  end

  def exchange_code(code)
    token_request(grant_type: 'authorization_code', code: code, redirect_uri: Salla::Config.redirect_uri)
  end

  # Salla refresh tokens work once: the response carries the next refresh token
  def refresh(refresh_token)
    token_request(grant_type: 'refresh_token', refresh_token: refresh_token)
  end

  def user_info(access_token)
    response = HTTParty.get(Salla::Config::USER_INFO_URL, headers: { 'Authorization' => "Bearer #{access_token}" })
    raise Error, "Salla user info failed (HTTP #{response.code})" unless response.success?

    response.parsed_response['data'] || {}
  end

  private

  def token_request(params)
    response = HTTParty.post(Salla::Config::TOKEN_URL, body: params.merge(client_id: Salla::Config.client_id,
                                                                          client_secret: Salla::Config.client_secret))
    body = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    raise Error, body['error_description'] || body['error'] || "HTTP #{response.code}" unless response.success? && body['access_token']

    body
  end
end
