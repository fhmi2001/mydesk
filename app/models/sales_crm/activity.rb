# Custom (MyDesk): one line of a deal's activity log (سجل النشاط): who did what and when. Written by the
# services, never edited.
class SalesCrm::Activity < ApplicationRecord
  KINDS = %w[created stage_changed amount_changed assignee_changed priority_changed won lost reopened note_added task_added
             task_done discarded restored].freeze

  belongs_to :account
  belongs_to :deal, class_name: 'SalesCrm::Deal', inverse_of: :activities
  belongs_to :user, optional: true

  validates :kind, inclusion: { in: KINDS }

  def readonly?
    persisted?
  end
end
