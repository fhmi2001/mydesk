# MyDesk: copy WhatsApp Web messages the gateway stored but never delivered (the platform was down when they came)
# into their conversations. Run through recover_lost.sh. Input: tmp/whatsapp_lost.json, rows from the gateway database.
# Messages are inserted without callbacks, so nothing is sent back to WhatsApp and no bot or automation reacts.
# Safe to re-run: a message already on the platform (same WhatsApp id) is skipped. DRY_RUN=1 only prints.
#
# rubocop:disable Rails/Output, Rails/SkipsModelValidations -- a console script; skipping callbacks is the point
require 'json'

dry = ENV['DRY_RUN'] == '1'

# The dashboard pages a conversation by message id ("before the oldest one shown"), so a late message must get an
# id below every newer message in its conversation, or it never shows. Takes the highest unused id below them.
def message_id_for(conversation, at)
  newer = conversation.messages.where('created_at > ?', at).minimum(:id)
  return if newer.nil?

  Message.connection.select_value(<<~SQL.squish) || raise("no free message id below #{newer}")
    SELECT max(g) FROM generate_series(1, #{newer.to_i - 1}) g WHERE NOT EXISTS (SELECT 1 FROM messages WHERE id = g)
  SQL
end
rows = JSON.parse(File.read('tmp/whatsapp_lost.json'))

rows.group_by { |r| r['instance'] }.each do |instance, messages|
  channel = Channel::Api.where('webhook_url LIKE ?', "%/chatwoot/webhook/#{instance}").first
  next puts("#{instance}: no inbox") unless channel

  inbox = channel.inbox
  puts "#{instance} -> #{inbox.name}"
  names = messages.reject { |r| r['from_me'] }.each_with_object({}) { |r, h| h[r['jid']] ||= r['push_name'].presence }
  phones = messages.each_with_object({}) { |r, h| h[r['jid']] ||= r['alt']&.split('@')&.first }

  # The gateway stores some messages twice (sent time, then delivery after reconnecting); keep the earlier
  messages.sort_by { |r| r['ts'] }.uniq { |r| r['wid'] }.each do |r|
    next puts("  skip unreadable #{r['wid']}") if r['type'] == 'placeholderMessage'
    next if inbox.messages.exists?(source_id: "WAID:#{r['wid']}")

    phone = phones[r['jid']] or next puts("  no phone number for #{r['jid']}")
    text = r['text'].presence || (r['type'] == 'audioMessage' ? '🎤 رسالة صوتية: افتحها من جوال الواتساب' : "[#{r['type']}]")
    at = Time.zone.at(r['ts'])
    puts ['  ', dry ? 'would add' : 'add', "+#{phone}", r['from_me'] ? 'out' : 'in',
          at.in_time_zone('Asia/Riyadh').strftime('%m-%d %H:%M'), text[0, 30].tr("\n", ' ')].join(' | ')
    next if dry

    contact = inbox.account.contacts.find_by(identifier: "#{phone}@s.whatsapp.net") ||
              inbox.account.contacts.create!(name: names[r['jid']] || "+#{phone}", phone_number: "+#{phone}",
                                             identifier: "#{phone}@s.whatsapp.net")
    contact_inbox = ContactInbox.find_or_create_by!(contact: contact, inbox: inbox) { |ci| ci.source_id = SecureRandom.uuid }
    conversation = inbox.conversations.where(contact: contact).where.not(status: :resolved).order(:id).last ||
                   inbox.conversations.create!(account: inbox.account, contact: contact, contact_inbox: contact_inbox)

    Message.insert_all!([{ id: message_id_for(conversation, at), account_id: inbox.account_id, inbox_id: inbox.id, conversation_id: conversation.id,
                           message_type: r['from_me'] ? 1 : 0, content: text, processed_message_content: text,
                           content_type: 0, status: 0, source_id: "WAID:#{r['wid']}",
                           sender_type: r['from_me'] ? nil : 'Contact', sender_id: r['from_me'] ? nil : contact.id,
                           content_attributes: {}, created_at: at, updated_at: at }.compact])
    # Back-dated messages would count as already seen; mark them unread
    seen = [conversation.agent_last_seen_at, at - 1.second].compact.min
    conversation.update_columns(last_activity_at: [conversation.last_activity_at, at].compact.max, agent_last_seen_at: seen,
                                assignee_last_seen_at: seen, updated_at: Time.current)
  end
end
# rubocop:enable Rails/Output, Rails/SkipsModelValidations
