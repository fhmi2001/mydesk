# Custom (MyDesk): one entry of a Sales CRM managed list (lead source, product, competitor, region, industry),
# managed by administrators in Sales settings. Archived rather than deleted, so a deal keeps its value in reports.
class SalesCrm::ListItem < ApplicationRecord
  LISTS = %w[lead_source product competitor region industry].freeze
  # The deal column each list fills
  DEAL_COLUMNS = LISTS.index_with { |list| :"#{list}_id" }.freeze
  # Lists that start with standard entries; the others start empty
  DEFAULTS = { 'lead_source' => %w[الموقع واتساب إنستغرام إحالة حملة معرض] }.freeze

  belongs_to :account

  validates :list, inclusion: { in: LISTS }
  validates :name, presence: true, length: { maximum: 100 }
  validate :name_unique_among_active

  default_scope { order(:position, :id) }
  scope :active, -> { where(archived_at: nil) }

  before_validation { self.name = name.to_s.squish }

  def self.for_list(account, list)
    account.crm_list_items.active.where(list: list)
  end

  # The standard entries of a list, created once for an account that has none
  def self.ensure_defaults!(account, list)
    names = DEFAULTS[list]
    return if names.blank? || account.crm_list_items.exists?(list: list)

    names.each_with_index { |name, position| account.crm_list_items.create!(list: list, name: name, position: position) }
  rescue ActiveRecord::RecordNotUnique
    nil # another request created them first
  end

  def archive!
    update!(archived_at: Time.current)
  end

  private

  def name_unique_among_active
    return if archived_at.present? || name.blank?

    taken = self.class.unscoped.where(account_id: account_id, list: list, archived_at: nil)
                .where('lower(name) = ?', name.downcase).where.not(id: id).exists?
    errors.add(:name, :taken) if taken
  end
end
