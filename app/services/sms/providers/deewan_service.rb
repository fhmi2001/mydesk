# Custom (MyDesk): sends SMS through Deewan (https://developer.deewan.sa/reference/sending-sms).
# Deewan is outbound only, so this channel sends replies and campaigns but never receives messages.
class Sms::Providers::DeewanService
  API_URL = 'https://apis.deewan.sa/sms/v1/messages'.freeze
  SUCCESS_REPLY_CODE = 0

  # What Deewan returns for a campaign send: the SMS id of the number and the id of the API request
  Receipt = Struct.new(:message_id, :request_id, keyword_init: true)

  # Raised for campaign sends so the campaign can record Deewan's reason (and request id) for each failed number
  class DeliveryError < StandardError
    attr_reader :request_id

    def initialize(message, request_id: nil)
      super(message)
      @request_id = request_id
    end
  end

  def initialize(channel:)
    @channel = channel
  end

  def send_message(contact_number, message)
    response = post(contact_number, message.outgoing_content, channel.phone_number)
    return sms_id(response) if delivered?(response)

    mark_message_failed(message, error_text(response))
    nil
  end

  # Campaigns may pick any of the channel's approved sender names; replies use the default one
  def send_text_message(contact_number, message_content, sender_name: nil)
    response = post(contact_number, message_content, sender_name || channel.phone_number)
    raise DeliveryError.new(error_text(response), request_id: response_body(response)['requestId']) unless delivered?(response)

    Receipt.new(message_id: sms_id(response), request_id: response_body(response)['requestId'])
  end

  # Handset delivery result of a sent SMS (https://developer.deewan.sa/reference/getting-sms-details).
  # Looked up by the SMS id; Deewan keeps these details for 3 months after sending.
  def message_details(message_id)
    response = HTTParty.get("#{API_URL}/#{message_id}", headers: headers)
    raise DeliveryError.new(error_text(response), request_id: response_body(response)['requestId']) unless delivered?(response)

    details = Array(response_body(response)['data']).first || {}
    { status: details['Status'], price: details['price'] }
  end

  private

  attr_reader :channel

  def post(contact_number, text, sender_name)
    HTTParty.post(API_URL, headers: headers, body: payload(contact_number, text, sender_name).to_json)
  end

  def payload(contact_number, text, sender_name)
    ascii = text.to_s.ascii_only?
    {
      # Deewan rejects raw Arabic for "unicode" ("Invalid Unicode data!", -17); it expects UCS-2 as hex
      'messageText' => ascii ? text : text.to_s.encode('UTF-16BE').unpack1('H*').upcase,
      'senderName' => sender_name,
      'messageType' => ascii ? 'text' : 'unicode',
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

  def response_body(response)
    response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
  end

  def delivered?(response)
    response.success? && response_body(response)['replyCode'] == SUCCESS_REPLY_CODE
  end

  def sms_id(response)
    response_body(response).dig('data', 'SentSMSIDs', 0, 'SMSId')
  end

  # The useful reason is in error.internalErrors (e.g. "Invalid Unicode data! (-17)"), not in replyMessage
  def error_text(response)
    body = response_body(response)
    details = Array(body.dig('error', 'internalErrors')).map { |item| "#{item['details']} (#{item['code']})" }
    error = details.join('; ').presence || body['replyMessage'].presence || "HTTP #{response.code}"
    Rails.logger.error("[#{channel.account_id}] Error sending SMS via Deewan: #{error}")
    error
  end

  def mark_message_failed(message, error)
    message.external_error = error
    message.status = :failed
    message.save!
  end
end
