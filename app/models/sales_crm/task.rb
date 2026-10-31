# Custom (MyDesk): a task (مهمة) for an agent, optionally tied to a contact, a deal and the conversation it came from.
class SalesCrm::Task < ApplicationRecord
  TITLE_MAX = 200

  belongs_to :account
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :creator, class_name: 'User', optional: true
  belongs_to :contact, optional: true
  belongs_to :deal, class_name: 'SalesCrm::Deal', optional: true, inverse_of: :tasks
  belongs_to :conversation, optional: true

  enum status: { open: 0, done: 1 }

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :description, length: { maximum: 5000 }

  # Open tasks whose time has come and that nobody has been reminded about yet
  scope :due, ->(now = Time.current) { open.where(due_at: ..now, reminded_at: nil) }

  def overdue?(now = Time.current)
    open? && due_at.present? && due_at < now
  end

  # What a reminder notification carries about the task (Notification#push_event_data reads the secondary actor)
  def push_event_data
    { id: id, title: title, due_at: due_at, status: status, deal_id: deal_id, contact_id: contact_id,
      conversation_id: conversation_id, type: 'crm_task' }
  end
end
