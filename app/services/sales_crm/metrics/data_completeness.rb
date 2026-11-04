# Custom (MyDesk): المؤشر 10, نسبة اكتمال البيانات: open deals that have every required field ÷ all open deals. Required
# for an open deal: an amount above zero, an expected close date and an owner.
module SalesCrm::Metrics::DataCompleteness
  COMPLETE_SQL = 'crm_deals.amount_cents > 0 AND crm_deals.close_date IS NOT NULL AND crm_deals.assignee_id IS NOT NULL'.freeze

  module_function

  def call(deals)
    open_count, complete_count = deals.open.pick(Arel.sql('COUNT(*)'), Arel.sql("COUNT(*) FILTER (WHERE #{COMPLETE_SQL})"))
    { open_count: open_count, complete_count: complete_count, rate: SalesCrm::Metrics::Ratio.percent(complete_count, open_count) }
  end

  def incomplete(deals)
    deals.open.where.not(Arel.sql(COMPLETE_SQL))
  end
end
