# Custom (MyDesk): المؤشر 4, نسبة الفوز: won ÷ (won + lost), by count; and by value for report 10
# (won value ÷ (won value + lost value), gap-analysis.md phase 3 decision 3). No closed deal gives nil.
module SalesCrm::Metrics::WinRate
  module_function

  def by_count(won_count, lost_count)
    SalesCrm::Metrics::Ratio.percent(won_count, won_count.to_i + lost_count.to_i)
  end

  def by_value(won_cents, lost_cents)
    SalesCrm::Metrics::Ratio.percent(won_cents, won_cents.to_i + lost_cents.to_i)
  end

  # Both, for the deals of `deals` closed in the period
  def call(deals, period)
    won = deals.won.where(won_at: period.range)
    lost = deals.lost.where(lost_at: period.range)
    won_count, won_cents = won.pick(Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(amount_cents), 0)'))
    lost_count, lost_cents = lost.pick(Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(amount_cents), 0)'))
    { won_count: won_count, lost_count: lost_count, won_cents: won_cents.to_i, lost_cents: lost_cents.to_i,
      by_count: by_count(won_count, lost_count), by_value: by_value(won_cents, lost_cents) }
  end
end
