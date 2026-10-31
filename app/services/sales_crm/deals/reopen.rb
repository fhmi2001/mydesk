# Custom (MyDesk): puts a won or lost deal back into the pipeline's first open stage
class SalesCrm::Deals::Reopen < SalesCrm::BaseService
  def perform(deal)
    fail!(:not_closed) if deal.open?
    stage = deal.pipeline.first_open_stage
    fail!(:stage_required) unless stage

    ActiveRecord::Base.transaction do
      from_stage_id = deal.stage_id
      deal.update!(stage: stage, status: :open, won_at: nil, lost_at: nil, lost_reason: nil, lost_note: nil,
                   position: (account.crm_deals.kept.where(stage_id: stage.id).maximum(:position) || 0) + 1)
      log(deal, 'reopened', from_stage_id: from_stage_id, to_stage_id: stage.id)
      broadcast('crm.deal_moved', id: deal.id, stage_id: stage.id, position: deal.position, pipeline_id: deal.pipeline_id,
                                  from_stage_id: from_stage_id)
      deal
    end
  end
end
