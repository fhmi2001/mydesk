# Custom (MyDesk): the actual win rate of each open stage, from the account's own history: of the deals created in
# the window that reached the stage (the funnel's rule, skipped stages included) and have since closed, the share
# that was won. Shown beside the stage's probability in Sales settings as a suggestion; it never changes it.
# Below MIN_CLOSED closed deals the rate is left out, since a handful of deals would only mislead.
class SalesCrm::Reports::StageWinRates < SalesCrm::Reports::Funnel
  MIN_CLOSED = 20

  def perform
    pipeline = self.pipeline || account.crm_pipelines.first
    return [] unless pipeline

    reached = reached_by_stage(pipeline)
    status_by_deal = deals.where(id: reached.values.reduce(Set.new, :|).to_a).where.not(status: :open).pluck(:id, :status).to_h
    pipeline.stages.select(&:open?).map { |stage| row_for(stage, reached[stage.id], status_by_deal) }
  end

  private

  def row_for(stage, deal_ids, status_by_deal)
    closed = deal_ids.count { |id| status_by_deal.key?(id) }
    won = deal_ids.count { |id| status_by_deal[id] == 'won' }
    { stage_id: stage.id, closed_count: closed, won_count: won, min_closed: MIN_CLOSED,
      win_rate: closed >= MIN_CLOSED ? (won * 100.0 / closed).round(1) : nil }
  end
end
