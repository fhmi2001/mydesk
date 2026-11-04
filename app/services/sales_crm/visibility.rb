# Custom (MyDesk): the one place that decides who sees which deals and tasks (docs/reports/gap-analysis.md,
# decisions ب and و). An administrator is the sales manager and sees everything; anyone else is an employee and
# only ever sees the deals they own (the owner is the assignee), whatever screen, report, link or export asks.
module SalesCrm::Visibility
  module_function

  def admin?(account, user)
    return false if user.nil?

    account.account_users.find_by(user_id: user.id)&.administrator? || false
  end

  # Without a user nobody's deals are visible: a service called with no acting user sees nothing rather than crashing
  def deals(account, user, relation = account.crm_deals.kept)
    return relation.none if user.nil?

    admin?(account, user) ? relation : relation.where(assignee_id: user.id)
  end

  # An employee's suggestions: a new deal or a note from the conversations assigned to them, and the follow-up, won
  # and lost messages of their own deals. A colleague's deal stays out even when the employee handles its conversation.
  def suggestions(account, user)
    base = account.crm_suggestions
    return base.none if user.nil?
    return base if admin?(account, user)

    from_conversations = base.where(kind: SalesCrm::Suggestion::CONVERSATION_KINDS,
                                    conversation_id: account.conversations.where(assignee_id: user.id).select(:id))
    from_deals = base.where(kind: SalesCrm::Suggestion::DEAL_KINDS,
                            deal_id: account.crm_deals.where(assignee_id: user.id).select(:id))
    from_conversations.or(from_deals)
  end

  # An employee's tasks: those on their own deals, those assigned to them, and the ones they wrote that belong to
  # no deal. A task on a colleague's deal stays out, since it would show that deal's title.
  def tasks(account, user)
    base = account.crm_tasks
    return base.none if user.nil?
    return base if admin?(account, user)

    own_deals = account.crm_deals.where(assignee_id: user.id).select(:id)
    base.where(deal_id: own_deals).or(base.where(assignee_id: user.id)).or(base.where(deal_id: nil, creator_id: user.id))
  end
end
