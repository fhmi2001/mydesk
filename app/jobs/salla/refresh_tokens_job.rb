# Custom (MyDesk): renews Salla access tokens before they expire (runs daily from config/schedule.yml)
class Salla::RefreshTokensJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Salla::TokenRefresher.due_hooks.each { |hook| Salla::TokenRefresher.new(hook: hook).perform }
  end
end
