# Custom (MyDesk): how many deals created in the period reached each stage of the pipeline, and the conversion between
# consecutive open stages (SalesCrm::Metrics::StageConversion: a skipped stage counts as entered).
class SalesCrm::Reports::Funnel < SalesCrm::Reports::Base
  def perform
    pipeline = self.pipeline || account.crm_pipelines.first
    return [] unless pipeline

    reached = reached_by_stage(pipeline)
    previous = nil
    pipeline.stages.map do |stage|
      count = reached[stage.id].size
      row = { stage_id: stage.id, name: stage.name, kind: stage.kind, color: stage.color, reached_count: count,
              conversion_from_previous: SalesCrm::Metrics::StageConversion.rate(count, previous) }
      previous = count if stage.open?
      row
    end
  end

  private

  # stage_id => set of deal ids (created in the period) that reached that stage
  def reached_by_stage(pipeline)
    deal_ids = deals.where(pipeline_id: pipeline.id, created_at: range).select(:id)
    SalesCrm::Metrics::StageConversion.reached(account, pipeline, deal_ids)
  end
end
