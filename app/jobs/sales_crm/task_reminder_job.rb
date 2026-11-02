# Custom (MyDesk): runs the task reminders for every account with the Sales CRM switched on (cron, every 5 min)
class SalesCrm::TaskReminderJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Account.find_each do |account|
      next unless account.feature_enabled?('sales_crm')

      SalesCrm::TaskReminders.new(account).perform
    rescue StandardError => e
      Rails.logger.error("[SalesCrm] reminders failed for account #{account.id}: #{e.class}: #{e.message}")
    end
  end
end
