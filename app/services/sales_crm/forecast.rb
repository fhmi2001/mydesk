# Custom (MyDesk): the numbers above the board, in one query:
# open deals, their total, the expected value (amount × the deal's probability: its own, else its stage's), and what was
# won / lost.
class SalesCrm::Forecast
  Result = Struct.new(:open_count, :open_total_cents, :expected_cents, :won_count, :won_total_cents, :lost_count, :lost_total_cents,
                      :currency, keyword_init: true)

  # `scope` is an authorized SalesCrm::Deal relation
  def self.call(scope, pipeline:)
    row = scope.where(pipeline_id: pipeline.id).joins(:stage).pick(Arel.sql(<<~SQL.squish))
      COUNT(*) FILTER (WHERE crm_deals.status = 0),
      COALESCE(SUM(amount_cents) FILTER (WHERE crm_deals.status = 0), 0),
      COALESCE(SUM(amount_cents * COALESCE(crm_deals.probability_override, crm_stages.probability)) FILTER (WHERE crm_deals.status = 0), 0) / 100,
      COUNT(*) FILTER (WHERE crm_deals.status = 1),
      COALESCE(SUM(amount_cents) FILTER (WHERE crm_deals.status = 1), 0),
      COUNT(*) FILTER (WHERE crm_deals.status = 2),
      COALESCE(SUM(amount_cents) FILTER (WHERE crm_deals.status = 2), 0)
    SQL

    Result.new(open_count: row[0].to_i, open_total_cents: row[1].to_i, expected_cents: row[2].to_i,
               won_count: row[3].to_i, won_total_cents: row[4].to_i, lost_count: row[5].to_i, lost_total_cents: row[6].to_i,
               currency: pipeline.currency)
  end
end
