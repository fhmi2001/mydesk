# Custom (MyDesk): applies a WhatsApp delivery / read receipt from the gateway to the platform message it
# belongs to. Messages sent from the platform carry the WhatsApp id as source_id "WAID:<id>". The status
# only moves forward (sent -> delivered -> read); a receipt also clears a timeout "failed" mark.
class WhatsappWeb::ReceiptProcessor
  STATUS_MAP = {
    'DELIVERY_ACK' => 'delivered',
    'READ' => 'read',
    'PLAYED' => 'read'
  }.freeze
  RANK = { 'failed' => -1, 'sent' => 0, 'delivered' => 1, 'read' => 2 }.freeze

  pattr_initialize [:inbox!, :payload!]

  def perform
    status = STATUS_MAP[data['status']]
    return if status.blank? || !receipt_for_sent_message?

    message = inbox.messages.outgoing.find_by(source_id: "WAID:#{data['keyId']}")
    return if message.nil? || RANK.fetch(message.status, 0) >= RANK[status]

    message.update!(status: status, external_error: nil)
  end

  private

  def data
    @data ||= payload['data'] || {}
  end

  def receipt_for_sent_message?
    payload['event'] == 'messages.update' && data['keyId'].present? && ActiveModel::Type::Boolean.new.cast(data['fromMe'])
  end
end
