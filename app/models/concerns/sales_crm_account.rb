# Custom (MyDesk): what the Sales CRM (المبيعات) adds to Account: its records (deleted in dependency order
# when the account goes) and its two settings. Included from app/models/account.rb with one marked line.
module SalesCrmAccount
  extend ActiveSupport::Concern

  included do
    has_many :crm_activities, class_name: 'SalesCrm::Activity', dependent: :delete_all
    has_many :crm_notes, class_name: 'SalesCrm::Note', dependent: :delete_all
    has_many :crm_tasks, class_name: 'SalesCrm::Task', dependent: :delete_all
    has_many :crm_deals, class_name: 'SalesCrm::Deal', dependent: :delete_all
    has_many :crm_stages, class_name: 'SalesCrm::Stage', dependent: :delete_all
    has_many :crm_pipelines, class_name: 'SalesCrm::Pipeline', dependent: :delete_all

    store_accessor :settings, :crm_agents_see_own_deals_only, :crm_default_currency
  end
end
