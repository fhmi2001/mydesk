# Custom (MyDesk): what the Sales CRM (المبيعات) adds to Account: its records (deleted in dependency order
# when the account goes) and its settings. Included from app/models/account.rb with one marked line.
module SalesCrmAccount
  extend ActiveSupport::Concern

  # Report thresholds an administrator can change in Sales settings (docs/reports/gap-analysis.md, decisions 1-2)
  DEFAULT_STALE_DAYS = 14
  DEFAULT_COVERAGE_MULTIPLE = 3

  included do
    has_many :crm_activities, class_name: 'SalesCrm::Activity', dependent: :delete_all
    has_many :crm_notes, class_name: 'SalesCrm::Note', dependent: :delete_all
    has_many :crm_tasks, class_name: 'SalesCrm::Task', dependent: :delete_all
    has_many :crm_deals, class_name: 'SalesCrm::Deal', dependent: :delete_all
    has_many :crm_stages, class_name: 'SalesCrm::Stage', dependent: :delete_all
    has_many :crm_pipelines, class_name: 'SalesCrm::Pipeline', dependent: :delete_all
    has_many :crm_lost_reasons, class_name: 'SalesCrm::LostReason', dependent: :delete_all
    has_many :crm_list_items, class_name: 'SalesCrm::ListItem', dependent: :delete_all
    has_many :crm_targets, class_name: 'SalesCrm::Target', dependent: :delete_all

    store_accessor :settings, :crm_default_currency, :crm_stale_days, :crm_coverage_multiple
  end

  # The one currency of the account's Sales section
  def crm_currency
    crm_default_currency.presence || 'SAR'
  end

  def crm_stale_days_value
    crm_stale_days.to_i.positive? ? crm_stale_days.to_i : DEFAULT_STALE_DAYS
  end

  def crm_coverage_multiple_value
    crm_coverage_multiple.to_f.positive? ? crm_coverage_multiple.to_f : DEFAULT_COVERAGE_MULTIPLE
  end
end
