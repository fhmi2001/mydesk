# Custom (MyDesk): the account's smart assistant (المساعد الذكي). It answers customers from the merchant's
# knowledge sources through the platform's own LLM key, replying as an account agent bot on the chosen inboxes.
# The bot is the stock Chatwoot mechanism: its inboxes start conversations as pending, and a handoff opens them.
# == Schema Information
#
# Table name: smart_assistants
#
#  id                  :bigint           not null, primary key
#  enabled             :boolean          default(FALSE), not null
#  handoff_message     :text
#  handoff_when_unsure :boolean          default(TRUE), not null
#  inbox_ids           :bigint           default([]), not null, is an Array
#  instructions        :text
#  max_replies         :integer          default(10), not null
#  name                :string           not null
#  reply_mode          :string           default("always"), not null
#  tone                :string           default("friendly"), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  agent_bot_id        :bigint
#
# Indexes
#
#  index_smart_assistants_on_account_id  (account_id) UNIQUE
#
class SmartAssistant < ApplicationRecord
  TONES = %w[friendly formal].freeze
  # always: every pending conversation; outside_working_hours: only while the inbox is closed
  REPLY_MODES = %w[always outside_working_hours].freeze
  MAX_INSTRUCTIONS_LENGTH = 4000

  belongs_to :account
  belongs_to :agent_bot, optional: true, dependent: :destroy
  has_many :sources, class_name: 'SmartAssistant::Source', dependent: :destroy
  has_many :chunks, through: :sources

  validates :account_id, uniqueness: true
  validates :name, presence: true, length: { maximum: 60 }
  validates :tone, inclusion: { in: TONES }
  validates :reply_mode, inclusion: { in: REPLY_MODES }
  validates :instructions, length: { maximum: MAX_INSTRUCTIONS_LENGTH }
  validates :handoff_message, length: { maximum: 500 }
  validates :max_replies, numericality: { only_integer: true, in: 1..50 }
  validate :inboxes_belong_to_account

  before_save :sync_agent_bot

  def self.for_account(account)
    find_or_initialize_by(account: account) { |assistant| assistant.name = I18n.t('smart_assistant.default_name') }
  end

  def inboxes
    account.inboxes.where(id: inbox_ids)
  end

  # The assistant keeps a conversation until it hands over or an agent assigns it to themselves
  def answers?(conversation)
    enabled? && agent_bot.present? && conversation.pending? && conversation.assignee_id.blank? &&
      handles_inbox?(conversation.inbox)
  end

  def handles_inbox?(inbox)
    inbox_ids.include?(inbox.id) && inbox.agent_bot == agent_bot
  end

  # Links the bot to the chosen inboxes while enabled, and to none while disabled, so a paused assistant
  # never leaves new conversations waiting in pending
  def sync_inbox_links!
    wanted = enabled? ? inbox_ids : []
    transaction do
      AgentBotInbox.where(agent_bot: agent_bot).where.not(inbox_id: wanted).destroy_all
      inboxes.where(id: wanted).find_each { |inbox| link_inbox!(inbox) }
    end
  end

  def monthly_replies
    Message.where(account_id: account_id, sender_type: 'AgentBot', sender_id: agent_bot_id, created_at: Time.current.all_month)
  end

  def replies_this_month
    monthly_replies.count
  end

  # Conversations on its inboxes that were handed to the team this month
  def handoffs_this_month
    ReportingEvent.where(account_id: account_id, inbox_id: inbox_ids, name: 'conversation_bot_handoff',
                         created_at: Time.current.all_month).count
  end

  def quota_reached?
    replies_this_month >= SmartAssistant::Config.monthly_reply_limit
  end

  private

  def link_inbox!(inbox)
    current = inbox.agent_bot_inbox
    return if current&.agent_bot_id == agent_bot_id && current.active?
    raise ActiveRecord::RecordInvalid, inbox_taken_error(inbox) if current && current.agent_bot_id != agent_bot_id

    (current || AgentBotInbox.new(inbox: inbox, agent_bot: agent_bot)).update!(status: :active)
  end

  def inbox_taken_error(inbox)
    errors.add(:inbox_ids, I18n.t('smart_assistant.errors.inbox_has_bot', inbox: inbox.name))
    self
  end

  def inboxes_belong_to_account
    return if inbox_ids.blank? || inboxes.count == inbox_ids.uniq.size

    errors.add(:inbox_ids, :invalid)
  end

  def sync_agent_bot
    self.agent_bot ||= AgentBot.new(account: account)
    agent_bot.update!(name: name, description: I18n.t('smart_assistant.bot_description'))
    # belongs_to autosave already ran before this callback, so a bot created here needs its id set by hand
    self.agent_bot_id = agent_bot.id
  end
end
