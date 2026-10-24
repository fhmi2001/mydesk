# Custom (MyDesk): sends SMS through Deewan (https://developer.deewan.sa/reference/sending-sms).
# Deewan is outbound only, so this channel sends replies and campaigns but never receives messages.
class Sms::Providers::DeewanService
  API_URL = 'https://apis.deewan.sa/sms/v1/messages'.freeze
  SUCCESS_REPLY_CODE = 0

  def initialize(channel:)
    @channel = channel
  end

  def send_message(contact_number, message)
    deliver(contact_number, message.outgoing_content, message)
  end

  def send_text_message(contact_number, message_content)
    deliver(contact_number, message_content)
  end

  private

  attr_reader :channel

  def deliver(contact_number, text, message = nil)
    response = HTTParty.post(API_URL, headers: headers, body: payload(contact_number, text).to_json)
    return response.parsed_response.dig('data', 'SentSMSIDs', 0, 'SMSId') if delivered?(response)

    handle_error(response, message)
    nil
  end

  def payload(contact_number, text)
    {
      'messageText' => text,
      'senderName' => channel.phone_number,
      # Deewan needs "unicode" for anything outside plain ASCII, such as Arabic text
      'messageType' => text.to_s.ascii_only? ? 'text' : 'unicode',
      # Deewan expects digits only, without the leading "+"
      'recipients' => contact_number.delete('+')
    }
  end

  def headers
    {
      'Authorization' => "Bearer #{channel.provider_config['api_key']}",
      'Content-Type' => 'application/json'
    }
  end

  def delivered?(response)
    response.success? && response.parsed_response['replyCode'] == SUCCESS_REPLY_CODE
  end

  def handle_error(response, message)
    error = response.parsed_response.is_a?(Hash) && response.parsed_response['replyMessage'].presence
    error ||= "HTTP #{response.code}"
    Rails.logger.error("[#{channel.account_id}] Error sending SMS via Deewan: #{error}")
    return if message.blank?

    message.external_error = error
    message.status = :failed
    message.save!
  end
end
