# Custom (MyDesk): brings a soft-deleted deal back at the end of its stage
class SalesCrm::Deals::Restore < SalesCrm::BaseService
  def perform(deal)
    return deal unless deal.discarded?

    ActiveRecord::Base.transaction do
      deal.update!(discarded_at: nil, position: (account.crm_deals.kept.where(stage_id: deal.stage_id).maximum(:position) || 0) + 1)
      log(deal, 'restored')
      broadcast('crm.deal_restored', id: deal.id, stage_id: deal.stage_id, pipeline_id: deal.pipeline_id)
      deal
    end
  end
end
