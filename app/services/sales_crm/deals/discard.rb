# Custom (MyDesk): soft-deletes a deal (restorable for 30 days, see PurgeDiscardedDealsJob)
class SalesCrm::Deals::Discard < SalesCrm::BaseService
  def perform(deal)
    return deal if deal.discarded?

    ActiveRecord::Base.transaction do
      deal.update!(discarded_at: Time.current)
      log(deal, 'discarded')
      broadcast('crm.deal_discarded', id: deal.id, stage_id: deal.stage_id, pipeline_id: deal.pipeline_id)
      deal
    end
  end
end
