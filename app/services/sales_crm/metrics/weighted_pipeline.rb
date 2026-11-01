# Custom (MyDesk): المؤشر 1, القيمة المرجّحة: Σ (amount × probability) over open deals. The probability is the deal's own
# (probability_override) when set, else its stage's. EXPRESSION is shared with the board's column totals and the
# forecast, which aggregate it per stage in the same query as their other numbers.
module SalesCrm::Metrics::WeightedPipeline
  EXPRESSION = 'crm_deals.amount_cents * COALESCE(crm_deals.probability_override, crm_stages.probability)'.freeze
  # SUM(...) / 100 in SQL, for queries already grouped or filtered
  SUM_SQL = "COALESCE(SUM(#{EXPRESSION}), 0) / 100".freeze

  module_function

  # `deals`: a SalesCrm::Deal relation (already scoped by SalesCrm::Visibility)
  def call(deals)
    deals.open.joins(:stage).pick(Arel.sql(SUM_SQL)).to_i
  end
end
