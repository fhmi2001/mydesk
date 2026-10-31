# Custom (MyDesk): a deal (صفقة). Lives in one stage of one pipeline; amount is kept in the currency's minor
# unit; status mirrors the stage kind so reports can query it; soft-deleted through discarded_at.
class SalesCrm::Deal < ApplicationRecord
  MAX_AMOUNT_CENTS = 10_000_000_000_000
  TITLE_MAX = 200

  belongs_to :account
  belongs_to :pipeline, class_name: 'SalesCrm::Pipeline', inverse_of: :deals
  belongs_to :stage, class_name: 'SalesCrm::Stage', inverse_of: :deals
  belongs_to :contact, optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :creator, class_name: 'User', optional: true
  belongs_to :conversation, optional: true
  has_many :tasks, class_name: 'SalesCrm::Task', dependent: :nullify, inverse_of: :deal
  has_many :notes, -> { order(created_at: :desc) }, class_name: 'SalesCrm::Note', dependent: :delete_all, inverse_of: :deal
  has_many :activities, -> { order(created_at: :desc, id: :desc) }, class_name: 'SalesCrm::Activity', dependent: :delete_all,
                                                                    inverse_of: :deal

  enum status: { open: 0, won: 1, lost: 2 }
  enum source: { manual: 0, conversation_source: 1, salla: 2 }, _prefix: :from

  validates :title, presence: true, length: { maximum: TITLE_MAX }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_AMOUNT_CENTS }
  validates :lost_reason, length: { maximum: 200 }
  validates :currency, inclusion: { in: SalesCrm::Pipeline::CURRENCIES }

  scope :kept, -> { where(discarded_at: nil) }
  scope :discarded, -> { where.not(discarded_at: nil) }

  before_validation :snapshot_contact_name
  before_save :normalize_search_columns

  # Amount as a decimal in major units, e.g. 50000.00 SAR
  def amount
    BigDecimal(amount_cents) / 100
  end

  def amount=(value)
    self.amount_cents = value.nil? ? 0 : (BigDecimal(value.to_s) * 100).round.to_i
  end

  def discarded? = discarded_at.present?

  def display_contact_name
    contact&.name.presence || contact_name_snapshot
  end

  private

  def snapshot_contact_name
    self.contact_name_snapshot = contact.name if contact && (contact_id_changed? || contact_name_snapshot.blank?)
  end

  def normalize_search_columns
    self.title_normalized = SalesCrm::Normalize.text(title)
    self.contact_name_normalized = SalesCrm::Normalize.text(display_contact_name)
  end
end
