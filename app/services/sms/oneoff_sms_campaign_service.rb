class Sms::OneoffSmsCampaignService
  pattr_initialize [:campaign!]

  def perform
    raise "Invalid campaign #{campaign.id}" if campaign.inbox.inbox_type != 'Sms' || !campaign.one_off?
    raise 'Completed Campaign' if campaign.completed?

    process_audience(audience_labels) if audience_labels.present?
    process_listed_numbers
    campaign.completed!
  end

  private

  def audience_labels
    audience_label_ids = campaign.audience.select { |audience| audience['type'] == 'Label' }.pluck('id')
    campaign.account.labels.where(id: audience_label_ids).pluck(:title)
  end

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def process_audience(audience_labels)
    campaign.account.contacts.tagged_with(audience_labels, any: true).each do |contact|
      next if contact.phone_number.blank?

      # Custom (MyDesk): every number gets a recipient row with its result; a number is sent to once
      recipient = campaign.sms_campaign_recipients.find_or_create_by!(account: campaign.account, phone_number: contact.phone_number)
      next unless recipient.queued?

      content = Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact).call(campaign.message)
      send_message(to: contact.phone_number, content: content, recipient: recipient)
    end
  end

  # Custom (MyDesk): typed or imported numbers have no contact, so they get the message as written
  def process_listed_numbers
    campaign.sms_campaign_recipients.queued.find_each do |recipient|
      send_message(to: recipient.phone_number, content: campaign.message, recipient: recipient)
    end
  end

  def send_message(to:, content:, recipient:)
    # Custom (MyDesk): only campaigns that picked a sender name pass it; others keep the channel default
    sender_options = campaign.sms_sender_name.present? ? { sender_name: campaign.sms_sender_name } : {}
    result = channel.send_text_message(to, content, **sender_options)
    # Deewan returns a receipt with its request id; Bandwidth returns only the message id
    message_id, request_id = result.respond_to?(:message_id) ? [result.message_id, result.request_id] : [result, nil]
    return recipient.mark_sent!(message_id, request_id: request_id) if message_id.present?

    recipient.mark_failed!('The SMS provider did not accept the message', request_id: request_id)
  rescue StandardError => e
    Rails.logger.error("[SMS Campaign #{campaign.id}] Failed to send to #{to}: #{e.message}")
    recipient.mark_failed!(e.message, request_id: e.try(:request_id))
  end
end
