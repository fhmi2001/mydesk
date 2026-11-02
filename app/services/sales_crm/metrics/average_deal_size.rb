# Custom (MyDesk): المؤشر 7, متوسط حجم الصفقة: value won ÷ deals won, over the deals won in the period. A won deal without
# an amount is left out (it would drag the average down for a missing number); it shows in data quality instead.
module SalesCrm::Metrics::AverageDealSize
  module_function

  def call(deals, period)
    count, total = deals.won.where(won_at: period.range).where('amount_cents > 0')
                        .pick(Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(amount_cents), 0)'))
    SalesCrm::Metrics::Ratio.average_cents(total, count)
  end
end
