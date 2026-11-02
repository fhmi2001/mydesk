# Custom (MyDesk): the headline numbers for a period, and the same for the period before it. Rates and averages with
# nothing to divide by are nil (shown as «—»).
class SalesCrm::Reports::Summary < SalesCrm::Reports::Base
  def perform
    { current: window(period), previous: window(period.previous), currency: currency }
  end

  private

  def window(window_period)
    closed = SalesCrm::Metrics::WinRate.call(deals, window_period)
    open_numbers.merge(
      created_count: deals.where(created_at: window_period.range).count,
      won_count: closed[:won_count], won_total_cents: closed[:won_cents],
      lost_count: closed[:lost_count], lost_total_cents: closed[:lost_cents],
      win_rate: closed[:by_count],
      avg_deal_cents: SalesCrm::Metrics::AverageDealSize.call(deals, window_period),
      avg_days_to_close: SalesCrm::Metrics::SalesCycle.call(deals, window_period)
    )
  end

  def open_numbers
    @open_numbers ||= { open_count: deals.open.count, open_total_cents: deals.open.sum(:amount_cents),
                        expected_cents: SalesCrm::Metrics::WeightedPipeline.call(deals) }
  end
end
