# Custom (MyDesk): permanently deletes deals that were soft-deleted more than 30 days ago (cron, daily)
class SalesCrm::PurgeDiscardedDealsJob < ApplicationJob
  queue_as :scheduled_jobs
  RETENTION = 30.days

  def perform
    SalesCrm::Deal.discarded.where(discarded_at: ...RETENTION.ago).in_batches(of: 500, &:destroy_all)
  end
end
