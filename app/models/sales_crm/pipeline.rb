# Custom (MyDesk): a sales pipeline (مسار) and its ordered stages. Each account has at least one.
class SalesCrm::Pipeline < ApplicationRecord
  CURRENCIES = %w[SAR AED USD EUR KWD BHD QAR OMR EGP JOD].freeze
  DEFAULT_NAME = 'المبيعات'.freeze

  belongs_to :account
  has_many :stages, -> { order(:position, :id) }, class_name: 'SalesCrm::Stage', dependent: :delete_all, inverse_of: :pipeline
  has_many :deals, class_name: 'SalesCrm::Deal', dependent: :restrict_with_error, inverse_of: :pipeline

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: :account_id }
  validates :currency, inclusion: { in: CURRENCIES }
  validate :currency_unchanged_when_locked

  default_scope { order(:position, :id) }

  def won_stage = stages.find(&:won?)
  def lost_stage = stages.find(&:lost?)
  def open_stages = stages.select(&:open?)
  def first_open_stage = open_stages.first

  # The currency cannot change once deals exist, so totals never mix currencies
  def currency_locked?
    persisted? && deals.exists?
  end

  private

  def currency_unchanged_when_locked
    return unless currency_changed? && currency_locked?

    errors.add(:currency, I18n.t('sales_crm.errors.currency_locked'))
  end
end
