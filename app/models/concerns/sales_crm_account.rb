# Custom (MyDesk): what the Sales CRM (المبيعات) adds to Account: its records (deleted in dependency order
# when the account goes) and its settings. Included from app/models/account.rb with one marked line.
module SalesCrmAccount
  extend ActiveSupport::Concern

  # Report thresholds an administrator can change in Sales settings (docs/reports/gap-analysis.md)
  DEFAULT_STALE_DAYS = 14
  DEFAULT_COVERAGE_MULTIPLE = 3
  # Conversation settings (docs/mydesk/CONVERSATION_SALES_PLAN.md): silent days before a follow-up, the window in
  # which an SMS campaign counts toward a new deal
  DEFAULT_FOLLOWUP_DAYS = 3
  DEFAULT_SMS_ATTRIBUTION_DAYS = 14

  included do
    has_many :crm_suggestions, class_name: 'SalesCrm::Suggestion', dependent: :delete_all
    has_many :crm_activities, class_name: 'SalesCrm::Activity', dependent: :delete_all
    has_many :crm_notes, class_name: 'SalesCrm::Note', dependent: :delete_all
    has_many :crm_tasks, class_name: 'SalesCrm::Task', dependent: :delete_all
    has_many :crm_deals, class_name: 'SalesCrm::Deal', dependent: :delete_all
    has_many :crm_stages, class_name: 'SalesCrm::Stage', dependent: :delete_all
    has_many :crm_pipelines, class_name: 'SalesCrm::Pipeline', dependent: :delete_all
    has_many :crm_lost_reasons, class_name: 'SalesCrm::LostReason', dependent: :delete_all
    has_many :crm_list_items, class_name: 'SalesCrm::ListItem', dependent: :delete_all
    has_many :crm_targets, class_name: 'SalesCrm::Target', dependent: :delete_all

    store_accessor :settings, :crm_default_currency, :crm_stale_days, :crm_coverage_multiple,
                   :crm_followup_days, :crm_sms_attribution_days, :crm_channel_sources, :crm_won_lost_messages
  end

  # The thank-you and "why not?" suggestions when a deal is won or lost: on unless the administrator turns them off
  def crm_won_lost_messages_value
    ActiveModel::Type::Boolean.new.cast(crm_won_lost_messages) != false
  end

  def crm_followup_days_value
    crm_followup_days.to_i.positive? ? crm_followup_days.to_i : DEFAULT_FOLLOWUP_DAYS
  end

  def crm_sms_attribution_days_value
    crm_sms_attribution_days.to_i.positive? ? crm_sms_attribution_days.to_i : DEFAULT_SMS_ATTRIBUTION_DAYS
  end

  # { 'inbox id' => lead source list item id }: the lead source a deal from that inbox's conversation starts with.
  # Kept per inbox, not per channel type, since WhatsApp Web and any other API inbox share Channel::Api.
  def crm_channel_sources_value
    (crm_channel_sources || {}).to_h.transform_keys(&:to_s)
  end

  def crm_lead_source_for_inbox(inbox_id)
    item_id = crm_channel_sources_value[inbox_id.to_s]
    item_id && crm_list_items.find_by(id: item_id, list: 'lead_source')
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
