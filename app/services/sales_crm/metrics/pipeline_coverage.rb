# Custom (MyDesk): المؤشر 3, تغطية خط الأنابيب: the open value expected to close in the period ÷ what is left of the
# target (target − won). Nothing left (target met, or no target) gives nil: there is no gap to cover.
# Compared with the account's coverage multiple (3 by default) to say whether the pipeline is enough.
module SalesCrm::Metrics::PipelineCoverage
  module_function

  # The open value whose expected close date falls in the period; deals without an amount add nothing
  def open_closing_cents(deals, period)
    deals.open.where(close_date: period.dates).sum(:amount_cents)
  end

  def call(open_cents:, target_cents:, won_cents:)
    remaining = target_cents.to_i - won_cents.to_i
    remaining.positive? ? SalesCrm::Metrics::Ratio.times(open_cents, remaining) : nil
  end
end
