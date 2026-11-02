# Custom (MyDesk): a suggestion (اقتراح) an employee accepts or dismisses; nothing it carries reaches a deal or a
# customer until they do. new_deal and note come from a conversation; follow_up, won_message and lost_question
# belong to a deal. The database keeps one pending suggestion per conversation or deal and kind.
class SalesCrm::Suggestion < ApplicationRecord
  class AlreadyDecided < StandardError; end

  CONVERSATION_KINDS = %w[new_deal note].freeze
  DEAL_KINDS = %w[follow_up won_message lost_question].freeze

  belongs_to :account
  belongs_to :conversation, optional: true
  belongs_to :contact, optional: true
  belongs_to :deal, class_name: 'SalesCrm::Deal', optional: true
  belongs_to :decided_by, class_name: 'User', optional: true

  enum kind: { new_deal: 0, note: 1, follow_up: 2, won_message: 3, lost_question: 4 }
  enum status: { pending: 0, accepted: 1, dismissed: 2 }
  # What made it: the smart assistant's reply, an automation rule, the follow-up schedule or the employee's own request
  enum origin: { assistant: 0, automation: 1, schedule: 2, user: 3 }, _prefix: :from

  validates :deal, presence: true, if: -> { DEAL_KINDS.include?(kind) }

  # The conversation panel shows it at once, wherever it came from (the assistant, a rule, the hourly follow-up)
  after_create_commit :announce

  def decide!(decision, user)
    raise AlreadyDecided unless pending?

    update!(status: decision, decided_by: user, decided_at: Time.current)
  end

  private

  # To those who may see it (SalesCrm::Visibility.suggestions): the conversation's assignee for a new deal or a note,
  # the deal's owner for its messages; SalesCrm::Broadcast adds the administrators
  def announce
    audience = DEAL_KINDS.include?(kind) ? deal&.assignee_id : conversation&.assignee_id
    SalesCrm::Broadcast.call(account, 'crm.suggestion_created',
                             { id: id, kind: kind, conversation_id: conversation&.display_id }, to: audience)
  end
end
