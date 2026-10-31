# Custom (MyDesk): shared plumbing for Sales CRM services: the account and acting user, translated
# validation errors, and stage lookup inside the account.
class SalesCrm::BaseService
  attr_reader :account, :user

  def initialize(account:, user: nil)
    @account = account
    @user = user
  end

  private

  def fail!(key, **args)
    raise SalesCrm::ValidationError, I18n.t("sales_crm.errors.#{key}", **args)
  end

  def priority_from(value)
    fail!(:invalid_priority) unless SalesCrm::Deal.priorities.key?(value.to_s)
    value.to_s
  end

  # The fields a deal takes from the managed lists, e.g. { product_id: 3 }; each id must be an item of that
  # list in this account (an archived item stays valid on deals that already have it)
  LIST_PARAMS = SalesCrm::ListItem::DEAL_COLUMNS.values.freeze

  def assign_list_items(deal, params)
    SalesCrm::ListItem::DEAL_COLUMNS.each do |list, column|
      next unless params.key?(column)

      id = params[column].presence
      next deal[column] = nil unless id
      next if deal[column] == id.to_i

      fail!(:invalid_list_item) unless account.crm_list_items.active.exists?(id: id, list: list)
      deal[column] = id.to_i
    end
  end

  def task_kind_from(value)
    fail!(:invalid_task_kind) unless SalesCrm::Task.kinds.key?(value.to_s)
    value.to_s
  end

  def forecast_category_from(value)
    return nil if value.blank?

    fail!(:invalid_forecast_category) unless SalesCrm::Deal.forecast_categories.key?(value.to_s)
    value.to_s
  end

  def probability_from(value)
    return nil if value.blank?

    number = Integer(SalesCrm::Normalize.digits(value.to_s), exception: false)
    fail!(:invalid_probability) unless number&.between?(0, 100)
    number
  end

  # An open deal needs an amount, an expected close date and an owner (docs/reports/gap-analysis.md, decisions د and 15)
  def require_open_essentials!(deal)
    return unless deal.open?

    fail!(:amount_required) unless deal.amount_cents.to_i.positive?
    fail!(:close_date_required) if deal.close_date.blank?
    fail!(:owner_required) if deal.assignee_id.blank?
  end

  def find_stage!(pipeline, stage_id)
    stage = pipeline.stages.find { |s| s.id == stage_id.to_i }
    fail!(:invalid_stage) unless stage
    stage
  end

  def log(deal, kind, data = {})
    SalesCrm::ActivityLog.record(deal: deal, kind: kind, user: user, data: data)
  end

  def broadcast(event, payload)
    SalesCrm::Broadcast.call(account, event, payload)
  end

  # Decimal (or Arabic-digit) amount string to cents; nil stays nil
  def cents_from(amount)
    return nil if amount.nil?
    return amount.to_i if amount.is_a?(Integer)

    (BigDecimal(SalesCrm::Normalize.digits(amount.to_s).delete(',٬ ').tr('٫', '.')) * 100).round.to_i
  rescue ArgumentError
    fail!(:invalid_amount)
  end
end
