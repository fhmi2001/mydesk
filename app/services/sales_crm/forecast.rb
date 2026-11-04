# Custom (MyDesk): the numbers above the board, in one query:
# open deals, their total, the expected value (SalesCrm::Metrics::WeightedPipeline), and what was won / lost.
class SalesCrm::Forecast
  Result = Struct.new(:open_count, :open_total_cents, :expected_cents, :won_count, :won_total_cents, :lost_count, :lost_total_cents,
                      :currency, keyword_init: true)

  # `scope` is an authorized SalesCrm::Deal relation
  def self.call(scope, pipeline:)
    open, won, lost = SalesCrm::Deal.statuses.values_at('open', 'won', 'lost').map { |value| "FILTER (WHERE crm_deals.status = #{value})" }
    row = scope.where(pipeline_id: pipeline.id).joins(:stage).pick(Arel.sql(<<~SQL.squish))
      COUNT(*) #{open},
      COALESCE(SUM(amount_cents) #{open}, 0),
      COALESCE(SUM(#{SalesCrm::Metrics::WeightedPipeline::EXPRESSION}) #{open}, 0) / 100,
      COUNT(*) #{won},
      COALESCE(SUM(amount_cents) #{won}, 0),
      COUNT(*) #{lost},
      COALESCE(SUM(amount_cents) #{lost}, 0)
    SQL

    Result.new(open_count: row[0].to_i, open_total_cents: row[1].to_i, expected_cents: row[2].to_i,
               won_count: row[3].to_i, won_total_cents: row[4].to_i, lost_count: row[5].to_i, lost_total_cents: row[6].to_i,
               currency: pipeline.currency)
  end
end
