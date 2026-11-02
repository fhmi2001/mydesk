# Custom (MyDesk): المؤشر 6, مدة دورة البيع: the average days from creation to the win, over the deals won in the period.
# None won gives nil.
module SalesCrm::Metrics::SalesCycle
  SECONDS_PER_DAY = 86_400

  module_function

  def call(deals, period)
    seconds = deals.won.where(won_at: period.range).pick(Arel.sql('AVG(EXTRACT(EPOCH FROM (won_at - crm_deals.created_at)))'))
    seconds ? (seconds.to_f / SECONDS_PER_DAY).round(1) : nil
  end
end
