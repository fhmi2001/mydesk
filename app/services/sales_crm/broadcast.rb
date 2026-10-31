# Custom (MyDesk): pushes a Sales CRM change over ActionCable, the same way ActionCableListener does for conversations
# (the frontend's actionCable helper maps crm.* events to the store). It reaches the administrators and the users in
# `to` (a deal's owner, a task's assignee...), never the whole account: an employee must not even learn that a
# colleague's deal moved (SalesCrm::Visibility).
module SalesCrm::Broadcast
  EVENTS = %w[crm.deal_created crm.deal_updated crm.deal_moved crm.deal_discarded crm.deal_restored
              crm.task_created crm.task_updated crm.task_completed crm.task_destroyed].freeze

  module_function

  def call(account, event, payload, to: [])
    raise ArgumentError, "unknown CRM event #{event}" unless EVENTS.include?(event)

    audience = account.account_users.administrator.pluck(:user_id) | Array(to).compact
    tokens = account.users.where(id: audience).pluck(:pubsub_token).uniq
    return if tokens.blank?

    data = payload.merge(account_id: account.id)
    data[:performer] = Current.user&.push_event_data if Current.user.present?
    ::ActionCableBroadcastJob.perform_later(tokens, event, data)
  end
end
