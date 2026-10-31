class Notification::RemoveDuplicateNotificationJob < ApplicationJob
  queue_as :default

  def perform(notification)
    return unless notification.is_a?(Notification)
    # Custom (MyDesk): a Sales CRM task reminder is its own thing, not a duplicate of the conversation's notifications
    return if notification.notification_type == 'crm_task_due'

    user_id = notification.user_id
    primary_actor_id = notification.primary_actor_id

    # Find older notifications with the same user and primary_actor_id
    duplicate_notifications = Notification.where(user_id: user_id, primary_actor_id: primary_actor_id)
                                          .where.not(notification_type: 'crm_task_due') # Custom (MyDesk)
                                          .order(created_at: :desc)

    # Skip the first one (the latest notification) and destroy the rest
    duplicate_notifications.offset(1).each(&:destroy)
  end
end
