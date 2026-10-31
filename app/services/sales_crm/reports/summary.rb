# Custom (MyDesk): the headline numbers for a period, and the same for the period before it
class SalesCrm::Reports::Summary < SalesCrm::Reports::Base
  def perform
    { current: window(range), previous: window(previous_range), currency: currency }
  end

  private

  def window(period)
    won = deals.won.where(won_at: period)
    lost = deals.lost.where(lost_at: period)
    won_count = won.count
    lost_count = lost.count
    won_total = won.sum(:amount_cents)
    open_numbers.merge(
      created_count: deals.where(created_at: period).count,
      won_count: won_count, won_total_cents: won_total, lost_count: lost_count, lost_total_cents: lost.sum(:amount_cents),
      win_rate: win_rate(won_count, lost_count), avg_deal_cents: won_count.zero? ? 0 : won_total / won_count,
      avg_days_to_close: average_days_to_close(won)
    )
  end

  def open_numbers
    @open_numbers ||= {
      open_count: deals.open.count,
      open_total_cents: deals.open.sum(:amount_cents),
      expected_cents: deals.open.joins(:stage).sum('crm_deals.amount_cents * crm_stages.probability') / 100
    }
  end
end
