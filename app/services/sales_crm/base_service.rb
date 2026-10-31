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
