# Custom (MyDesk): permanently deletes suggestions dismissed more than 30 days ago (cron, daily)
class SalesCrm::PurgeDismissedSuggestionsJob < ApplicationJob
  queue_as :scheduled_jobs
  RETENTION = 30.days

  def perform
    SalesCrm::Suggestion.dismissed.where(decided_at: ...RETENTION.ago).in_batches(of: 500).delete_all
  end
end
