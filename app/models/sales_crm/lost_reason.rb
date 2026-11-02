# Custom (MyDesk): one entry of the account's lost reasons list (أسباب الخسارة), managed in Sales settings
class SalesCrm::LostReason < ApplicationRecord
  DEFAULTS = ['السعر مرتفع', 'اختار منافساً', 'لا رد من العميل', 'لا يحتاج الخدمة الآن', 'أخرى'].freeze

  belongs_to :account

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: :account_id, case_sensitive: false }

  default_scope { order(:position, :id) }

  before_validation { self.name = name.to_s.squish }

  # The five standard reasons, created once for an account that has none
  def self.ensure_defaults!(account)
    return if account.crm_lost_reasons.exists?

    DEFAULTS.each_with_index { |name, position| account.crm_lost_reasons.create!(name: name, position: position) }
  rescue ActiveRecord::RecordNotUnique
    nil # another request created them first
  end
end
