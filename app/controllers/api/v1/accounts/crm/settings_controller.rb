# Custom (MyDesk): account-level CRM settings (administrators): the Sales section's one currency
# (changeable only while there are no deals), and the report thresholds (stale days, pipeline coverage multiple)
class Api::V1::Accounts::Crm::SettingsController < Api::V1::Accounts::Crm::BaseController
  before_action :check_admin_authorization?

  def show
    render json: settings_json
  end

  def update
    attrs = params.require(:settings).permit(:default_currency, :stale_days, :coverage_multiple, :followup_days,
                                             :sms_attribution_days, :won_lost_messages, channel_sources: {})
    assign_thresholds(attrs)
    assign_conversation_settings(attrs)
    Current.account.save!
    SalesCrm::Currency.change!(Current.account, attrs[:default_currency]) if attrs.key?(:default_currency)
    render json: settings_json
  end

  private

  def assign_thresholds(attrs)
    Current.account.crm_stale_days = whole_number!(attrs[:stale_days], 1..365) if attrs.key?(:stale_days)
    Current.account.crm_coverage_multiple = multiple!(attrs[:coverage_multiple]) if attrs.key?(:coverage_multiple)
  end

  # Custom (MyDesk): the conversation settings (CONVERSATION_SALES_PLAN.md)
  def assign_conversation_settings(attrs)
    account = Current.account
    account.crm_followup_days = whole_number!(attrs[:followup_days], 1..30, :invalid_followup_days) if attrs.key?(:followup_days)
    if attrs.key?(:sms_attribution_days)
      account.crm_sms_attribution_days = whole_number!(attrs[:sms_attribution_days], 1..90, :invalid_attribution_days)
    end
    account.crm_channel_sources = channel_sources!(attrs[:channel_sources]) if attrs.key?(:channel_sources)
    account.crm_won_lost_messages = ActiveModel::Type::Boolean.new.cast(attrs[:won_lost_messages]) if attrs.key?(:won_lost_messages)
  end

  # Merges the given inboxes into the map; an inbox given nothing loses its lead source
  def channel_sources!(given)
    account = Current.account
    map = account.crm_channel_sources_value
    given.to_h.each do |inbox_id, item_id|
      raise_invalid(:invalid_channel_source) unless account.inboxes.exists?(id: inbox_id)
      next map.delete(inbox_id.to_s) if item_id.blank?

      raise_invalid(:invalid_channel_source) unless account.crm_list_items.exists?(id: item_id, list: 'lead_source')

      map[inbox_id.to_s] = item_id.to_i
    end
    map
  end

  def whole_number!(value, range, error = :invalid_stale_days)
    number = Integer(SalesCrm::Normalize.digits(value.to_s), exception: false)
    raise_invalid(error) unless number && range.cover?(number)

    number
  end

  def raise_invalid(error)
    raise SalesCrm::ValidationError, I18n.t("sales_crm.errors.#{error}")
  end

  def multiple!(value)
    number = Float(SalesCrm::Normalize.digits(value.to_s), exception: false)
    raise SalesCrm::ValidationError, I18n.t('sales_crm.errors.invalid_coverage') unless number&.between?(0.5, 20)

    number.round(1)
  end

  def settings_json
    account = Current.account
    { default_currency: account.crm_currency, currencies: SalesCrm::Pipeline::CURRENCIES,
      currency_locked: SalesCrm::Currency.locked?(account),
      stale_days: account.crm_stale_days_value, coverage_multiple: account.crm_coverage_multiple_value,
      followup_days: account.crm_followup_days_value, sms_attribution_days: account.crm_sms_attribution_days_value,
      channel_sources: account.crm_channel_sources_value, won_lost_messages: account.crm_won_lost_messages_value }
  end
end
