# Custom (MyDesk): one bell / push notification per task when its time comes. Chatwoot notifications hang off
# a conversation, so the reminder points at the task's conversation or the contact's latest one that the
# assignee can open; a task with none is marked reminded and only counts in the overdue badge.
class SalesCrm::TaskReminders
  CANDIDATES = 20

  def initialize(account)
    @account = account
  end

  def perform(now: Time.current)
    @account.crm_tasks.due(now).includes(:assignee, :contact, :conversation).find_each do |task|
      ActiveRecord::Base.transaction do
        notify(task)
        task.update_columns(reminded_at: now) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  private

  def notify(task)
    return if task.assignee.nil?

    conversation = conversation_for(task)
    return if conversation.nil?

    NotificationBuilder.new(notification_type: 'crm_task_due', user: task.assignee, account: @account,
                            primary_actor: conversation, secondary_actor: task).perform
  end

  def conversation_for(task)
    account_user = AccountUser.find_by(account_id: @account.id, user_id: task.assignee_id)
    return nil unless account_user

    context = { user: task.assignee, account: @account, account_user: account_user }
    candidates(task).find { |conversation| ConversationPolicy.new(context, conversation).show? }
  end

  def candidates(task)
    list = [task.conversation].compact
    return list unless task.contact

    list + task.contact.conversations.where(account_id: @account.id).order(last_activity_at: :desc).limit(CANDIDATES).to_a
  end
end
