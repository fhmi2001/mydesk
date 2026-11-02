# Custom (MyDesk): an employee's sales target (هدف) for one month, in the account's currency minor unit.
# The team target is the sum of the employees' targets for the same months; it is never stored.
class SalesCrm::Target < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :period_start, :period_end, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: { scope: %i[account_id period_start] }

  # Targets whose month falls inside the date range (whole months: a quarter is the sum of its three months)
  scope :within, ->(range) { where(period_start: range.begin..range.end) }

  def self.team_cents(account, range)
    account.crm_targets.within(range).sum(:amount_cents)
  end

  def self.month_range(month)
    start = Date.strptime(month.to_s, '%Y-%m').beginning_of_month
    start..start.end_of_month
  end
end
