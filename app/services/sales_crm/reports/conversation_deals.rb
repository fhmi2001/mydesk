# Custom (MyDesk): التقرير 22, من المحادثة إلى الصفقة (CONVERSATION_SALES_PLAN.md, phase 0 question 7): how many of the
# period's conversations became deals, and how many of those were won, per channel (inbox) and, for the manager, per
# employee handling the conversation. A conversation counts once however many deals came from it. An employee sees the
# conversations assigned to them and their own deals (SalesCrm::Visibility).
class SalesCrm::Reports::ConversationDeals < SalesCrm::Reports::Report
  KEY = 'conversation_deals'.freeze

  def build
    totals = figures(conversations)
    { totals: totals, empty: totals[:conversation_count].zero?, inboxes: inbox_rows, assignees: assignee_rows }
  end

  # cell: inbox_id and / or conversation_assignee_id ('none' for unassigned conversations)
  def drill_scope(cell)
    scope = conversations
    scope = scope.where(inbox_id: cell[:inbox_id].to_i) if cell[:inbox_id].present?
    if cell.key?(:conversation_assignee_id)
      value = cell[:conversation_assignee_id].to_s
      scope = scope.where(assignee_id: value == NONE ? nil : value.to_i)
    end
    from_conversations(scope)
  end

  private

  def drill_order = { created_at: :desc, id: :desc }

  # The period's conversations: all for the manager (or one employee's when filtered), an employee's own otherwise
  def conversations
    scope = account.conversations.where(created_at: period.range)
    assignee_id ? scope.where(assignee_id: assignee_id) : scope
  end

  def from_conversations(scope) = deals.where(conversation_id: scope.select(:id))

  def figures(scope)
    total = scope.count
    with_deal = from_conversations(scope).distinct.count(:conversation_id)
    won = from_conversations(scope).won
    { conversation_count: total, deal_count: with_deal, won_count: won.count, won_cents: won.sum(:amount_cents),
      conversion: SalesCrm::Metrics::Ratio.percent(with_deal, total) }
  end

  def inbox_rows
    ids = conversations.distinct.pluck(:inbox_id)
    rows = account.inboxes.where(id: ids).map do |inbox|
      figures(conversations.where(inbox_id: inbox.id)).merge(inbox_id: inbox.id, name: inbox.name, channel: inbox.channel_type,
                                                             cell: { inbox_id: inbox.id })
    end
    rows.sort_by { |row| -row[:conversation_count] }
  end

  def assignee_rows
    return nil unless team_view?

    ids = conversations.distinct.pluck(:assignee_id)
    people = names(ids)
    rows = ids.map do |id|
      figures(conversations.where(assignee_id: id)).merge(assignee_id: id, name: people[id],
                                                          cell: { conversation_assignee_id: id || NONE })
    end
    rows.sort_by { |row| -row[:conversation_count] }
  end
end
