# Custom (MyDesk): automation action "send a message through a channel". Sends the message to the
# conversation's contact through another inbox the account has (Deewan / Bandwidth SMS, Twilio SMS,
# WhatsApp Web, email), e.g. an SMS when a WhatsApp conversation is resolved.
#
# The message goes into the contact's open conversation in that inbox, or a new one created as resolved
# so automated notices do not fill the team's queue (a customer reply reopens it). Channels that cannot
# start a conversation on their own (WhatsApp Cloud outside templates, Facebook, Instagram, Telegram...)
# are not supported.
class AutomationRules::SendViaInboxService
  pattr_initialize [:rule!, :conversation!, :inbox!, :message!]

  def self.supported?(inbox)
    case inbox&.channel_type
    when 'Channel::Sms', 'Channel::Email' then true
    when 'Channel::TwilioSms' then inbox.channel.medium == 'sms'
    when 'Channel::Api' then WhatsappWeb::Config.instance_name_for(inbox).present?
    else false
    end
  end

  def perform
    return unless self.class.supported?(inbox) && message.present? && address.present?

    Messages::MessageBuilder.new(nil, target_conversation, message_params).perform
  end

  private

  def contact
    conversation.contact
  end

  # Where the channel reaches the contact: email for email inboxes, the mobile number otherwise
  def address
    inbox.channel_type == 'Channel::Email' ? contact.email : contact.phone_number
  end

  def target_conversation
    return conversation if inbox.id == conversation.inbox_id

    contact_inbox.conversations.where.not(status: :resolved).last || new_conversation
  end

  # Reuse the contact's address in the inbox; a new one would start a separate thread each time
  def contact_inbox
    @contact_inbox ||= contact.contact_inboxes.where(inbox_id: inbox.id).last ||
                       ContactInboxBuilder.new(contact: contact, inbox: inbox).perform
  end

  def new_conversation
    contact_inbox.conversations.create!(account_id: inbox.account_id, inbox_id: inbox.id, contact_id: contact.id,
                                        status: :resolved)
  end

  def message_params
    { content: message, private: false, content_attributes: { automation_rule_id: rule.id } }
  end
end
