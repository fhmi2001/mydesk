# Custom (MyDesk): sets the employees' targets for one month in one go: { user_id => amount }. A blank amount
# removes that employee's target for the month. Administrators only (checked by the caller).
class SalesCrm::Targets::Set < SalesCrm::BaseService
  def perform(month:, amounts:)
    range = SalesCrm::Target.month_range(month)
    ActiveRecord::Base.transaction do
      amounts.to_h.each { |user_id, amount| set_one(account.users.find(user_id), range, amount) }
    end
    account.crm_targets.where(period_start: range.begin)
  rescue Date::Error
    fail!(:invalid_month)
  end

  private

  def set_one(employee, range, amount)
    target = account.crm_targets.find_or_initialize_by(user: employee, period_start: range.begin)
    cents = cents_from(amount.to_s.presence)
    return target.destroy! if cents.nil?

    target.update!(period_end: range.end, amount_cents: cents)
  end
end
