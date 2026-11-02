# Custom (MyDesk): the conversation side of the Sales demo data (docs/mydesk/CONVERSATION_SALES_PLAN.md, phase 5), added
# by SalesCrm::DemoSeed to its own demo account only, never to a real one, so demo conversations never sit in a real
# inbox. Two demo inboxes (website and WhatsApp), a live chat campaign and an SMS campaign with recipients and prices.
# About half the deals come from a conversation: the customer writes, the owner replies after anything from two
# minutes to a day (Chatwoot's first_response event), and they write back and forth until the deal closes. Some
# conversations become no deal, some deals come from the chat campaign or after an SMS, and suggestions sit in their
# three states. Its own random generator keeps the deals' numbers exactly as DemoSeed draws them.
# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Rails/SkipsModelValidations -- demo data built step by step, written straight to the tables with its past timestamps
class SalesCrm::DemoConversations
  SEED = SalesCrm::DemoSeed::SEED + 2
  CONVERSATION_SHARE = 0.5
  STRAY_CONVERSATIONS = 60
  # Minutes to the first reply: spread over the five buckets of the response speed report
  REPLY_MINUTES = [1, 2, 3, 4, 8, 15, 25, 40, 75, 110, 180, 400, 900, 1600, 2400].freeze
  CHAT_CAMPAIGN_SHARE = 0.25
  SMS_RECIPIENTS = 60
  SUGGESTION_STATES = %w[pending pending pending accepted accepted dismissed dismissed].freeze
  CUSTOMER_LINES = ['السلام عليكم، أبغى عرض سعر', 'كم سعر الباقة السنوية؟', 'هل يوجد خصم للكميات؟', 'متى يمكن البدء؟',
                    'أرسلوا لي التفاصيل على الواتساب', 'تمام، سأراجع مع الإدارة'].freeze
  TEAM_LINES = ['أهلاً بك، يسعدنا خدمتك', 'أرسلت لك العرض الآن', 'هل اطلعت على العرض؟', 'نقدر نبدأ الأسبوع القادم',
                'أي استفسار أنا حاضر'].freeze

  def self.clear(account)
    SalesCrm::Suggestion.where(account_id: account.id).delete_all
    SmsCampaignRecipient.where(account_id: account.id).delete_all
    ReportingEvent.where(account_id: account.id).delete_all
    Message.where(account_id: account.id).delete_all
    Conversation.where(account_id: account.id).delete_all
    ContactInbox.where(inbox_id: account.inboxes.select(:id)).delete_all
    Campaign.where(account_id: account.id).delete_all
  end

  def initialize(seed)
    @seed = seed
    @account = seed.account
    @rng = Random.new(SEED)
  end

  def perform
    @web, @whatsapp, @sms_inbox = inboxes
    @chat_campaign, @sms_campaign = campaigns
    deals = @account.crm_deals.where.not(contact_id: nil).order(:id).to_a
    @conversations = []
    deals.each { |deal| from_conversation(deal) if @rng.rand < CONVERSATION_SHARE }
    STRAY_CONVERSATIONS.times { stray }
    sms_campaign(deals)
    suggestions
  end

  private

  attr_reader :account

  def zone = SalesCrm::TimeZone.for(account)
  def first_day = @seed.anchor - SalesCrm::DemoSeed::DAYS + 1
  def cutoff = zone.local(@seed.anchor.year, @seed.anchor.month, @seed.anchor.day, 17)
  def pick(list) = list[@rng.rand(list.size)]

  def inboxes
    web = find_inbox('الموقع (تجريبي)') { Channel::WebWidget.create!(account: account, website_url: 'https://demo.mydesk.test') }
    whatsapp = find_inbox('واتساب (تجريبي)') { Channel::Api.create!(account: account) }
    sms = find_inbox('SMS (تجريبي)') do
      Channel::Sms.create!(account: account, provider: 'default', phone_number: "+9665#{format('%08d', account.id)}")
    end
    [web, whatsapp, sms]
  end

  def find_inbox(name)
    account.inboxes.find_by(name: name) || account.inboxes.create!(name: name, channel: yield)
  end

  def campaigns
    chat = account.campaigns.create!(inbox: @web, title: 'ترحيب زوار الموقع', message: 'مرحباً! هل تبحث عن باقة مناسبة؟')
    sms = account.campaigns.create!(inbox: @sms_inbox, title: 'عرض نهاية الربع', message: 'خصم 15% على الباقات السنوية')
    [chat, sms]
  end

  # A deal that came from a conversation: the customer writes before the deal, the owner replies, then back and forth
  def from_conversation(deal)
    start = [deal.created_at - (1 + @rng.rand(48)).hours, zone.local(first_day.year, first_day.month, first_day.day, 9)].max
    inbox = @rng.rand < 0.5 ? @web : @whatsapp
    campaign = inbox == @web && @rng.rand < CHAT_CAMPAIGN_SHARE ? @chat_campaign : nil
    conversation_id = conversation(deal.contact_id, inbox, deal.assignee_id, start, open: deal.open?, campaign: campaign)
    last_reply = exchange(conversation_id, inbox, deal, start)
    attrs = { conversation_id: conversation_id, active_conversation_id: conversation_id, source: SalesCrm::Deal.sources['conversation_source'] }
    if last_reply
      attrs[:last_message_at] = last_reply
      attrs[:last_touch_at] = [deal.last_activity_at, last_reply].compact.max
    end
    direct = { campaign_id: campaign&.id, campaign_attribution: campaign && SalesCrm::Deal.campaign_attributions['direct'] }
    deal.update_columns(campaign ? attrs.merge(direct) : attrs)
  end

  # The customer's first message, the owner's first reply (and its first_response event), then a few more each way
  # until the deal closes; returns the owner's last reply, or nil when there was none
  def exchange(conversation_id, inbox, deal, start)
    rows = [message(conversation_id, inbox, start, incoming: true, text: pick(CUSTOMER_LINES))]
    minutes = pick(REPLY_MINUTES)
    reply = start + minutes.minutes
    return insert(rows) && nil if reply > cutoff

    rows << message(conversation_id, inbox, reply, sender_id: deal.assignee_id, text: pick(TEAM_LINES))
    first_response(conversation_id, inbox, deal.assignee_id, start, reply)
    last = reply
    ending = [deal.won_at || deal.lost_at || cutoff, cutoff].min
    @rng.rand(4).times do
      written = last + (6 + @rng.rand(72)).hours
      break if written > ending

      customer = @rng.rand < 0.5
      rows << message(conversation_id, inbox, written, incoming: customer, sender_id: deal.assignee_id,
                                                       text: pick(customer ? CUSTOMER_LINES : TEAM_LINES))
      last = written unless customer
    end
    insert(rows)
    last
  end

  # A conversation that became no deal
  def stray
    contact_id = account.contacts.order(:id).offset(@rng.rand(account.contacts.count)).pick(:id)
    owner = @seed.employee(@rng.rand(SalesCrm::DemoSeed::EMPLOYEES.size))
    start = zone.local(first_day.year, first_day.month, first_day.day, 9) + @rng.rand(SalesCrm::DemoSeed::DAYS).days + @rng.rand(8).hours
    return if start > cutoff

    inbox = @rng.rand < 0.5 ? @web : @whatsapp
    conversation_id = conversation(contact_id, inbox, owner.id, start, open: @rng.rand < 0.3)
    @conversations << conversation_id
    insert([message(conversation_id, inbox, start, incoming: true, text: pick(CUSTOMER_LINES))])
  end

  def conversation(contact_id, inbox, assignee_id, start, open:, campaign: nil)
    contact_inbox_id = ContactInbox.find_or_create_by!(contact_id: contact_id, inbox_id: inbox.id) do |row|
      row.source_id = "demo-#{contact_id}"
    end.id
    Conversation.insert_all([{ account_id: account.id, inbox_id: inbox.id, contact_id: contact_id, contact_inbox_id: contact_inbox_id,
                               assignee_id: assignee_id, campaign_id: campaign&.id, status: Conversation.statuses[open ? 'open' : 'resolved'],
                               created_at: start, updated_at: start, last_activity_at: start }], returning: %w[id]).rows.first.first
  end

  def message(conversation_id, inbox, written, text:, incoming: false, sender_id: nil)
    { account_id: account.id, inbox_id: inbox.id, conversation_id: conversation_id, content: text,
      message_type: Message.message_types[incoming ? 'incoming' : 'outgoing'], private: false,
      sender_type: incoming ? nil : 'User', sender_id: incoming ? nil : sender_id, created_at: written, updated_at: written }
  end

  def insert(rows)
    Message.insert_all(rows)
    true
  end

  def first_response(conversation_id, inbox, user_id, start, reply)
    ReportingEvent.insert_all([{ account_id: account.id, inbox_id: inbox.id, conversation_id: conversation_id, user_id: user_id,
                                 name: 'first_response', value: reply - start, value_in_business_hours: reply - start,
                                 event_start_time: start, event_end_time: reply, created_at: reply, updated_at: reply }])
  end

  # The SMS campaign went to customers (numbers stored in the forms the app meets); a deal created within the window
  # after it, not already credited to the chat campaign, is credited to it as influenced
  def sms_campaign(deals)
    sent_at = zone.local(@seed.anchor.year, @seed.anchor.month, 1, 11)
    contacts = account.contacts.order(:id).limit(SMS_RECIPIENTS).pluck(:id, :phone_number)
    rows = contacts.each_with_index.map do |(_, phone), i|
      stored = i.even? ? phone : phone.delete_prefix('+')
      { account_id: account.id, campaign_id: @sms_campaign.id, phone_number: stored, status: SmsCampaignRecipient.statuses['sent'],
        sent_at: sent_at, delivery_price: (i % 10).zero? ? nil : 0.05, created_at: sent_at, updated_at: sent_at }
    end
    SmsCampaignRecipient.insert_all(rows)
    window = sent_at..(sent_at + @seed.account.crm_sms_attribution_days_value.days)
    reached = contacts.map(&:first)
    deals.each do |deal|
      next unless reached.include?(deal.contact_id) && window.cover?(deal.created_at) && deal.reload.campaign_id.nil?

      deal.update_columns(campaign_id: @sms_campaign.id, campaign_attribution: SalesCrm::Deal.campaign_attributions['influenced'])
    end
  end

  # Suggestions in their three states: a deal from a conversation that became none yet, taken or dismissed
  def suggestions
    manager = @seed.manager
    rows = @conversations.first(SUGGESTION_STATES.size).each_with_index.map do |conversation_id, i|
      status = SUGGESTION_STATES[i]
      decided = status == 'pending' ? { decided_by_id: nil, decided_at: nil } : { decided_by_id: manager.id, decided_at: cutoff - i.days }
      { account_id: account.id, conversation_id: conversation_id, kind: SalesCrm::Suggestion.kinds['new_deal'],
        status: SalesCrm::Suggestion.statuses[status], origin: SalesCrm::Suggestion.origins['assistant'],
        content: { product: 'باقة الواتساب', quantity: '12', city: 'الرياض', summary: 'يطلب عرض سعر لاشتراك سنوي' },
        created_at: cutoff - (i + 2).days, updated_at: cutoff - (i + 1).days }.merge(decided)
    end
    SalesCrm::Suggestion.insert_all(rows) if rows.any?
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/ParameterLists, Rails/SkipsModelValidations
