module PriorityActivityMessageHandler
  extend ActiveSupport::Concern

  private

  def priority_change_activity(user_name)
    old_priority, new_priority = previous_changes.values_at('priority')[0]
    return unless priority_change?(old_priority, new_priority)

    user = Current.executed_by.instance_of?(AutomationRule) ? I18n.t('automation.system_name') : user_name
    content = build_priority_change_content(user, old_priority, new_priority)

    ::Conversations::ActivityMessageJob.perform_later(self, activity_message_params(content)) if content
  end

  def priority_change?(old_priority, new_priority)
    old_priority.present? || new_priority.present?
  end

  def build_priority_change_content(user_name, old_priority = nil, new_priority = nil)
    change_type = get_priority_change_type(old_priority, new_priority)

    I18n.t("conversations.activity.priority.#{change_type}", user_name: user_name, new_priority: priority_name(new_priority),
                                                             old_priority: priority_name(old_priority))
  end

  # Custom (MyDesk): the priority in the reader's language («عالية»); locales without names keep the raw value
  def priority_name(priority)
    return priority if priority.blank?

    I18n.t("conversations.priority_names.#{priority}", default: priority.to_s)
  end

  def get_priority_change_type(old_priority, new_priority)
    case [old_priority.present?, new_priority.present?]
    when [true, true] then 'updated'
    when [false, true] then 'added'
    when [true, false] then 'removed'
    end
  end
end
