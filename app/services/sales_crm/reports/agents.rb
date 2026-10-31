# Custom (MyDesk): one row per agent: open, won and lost deals in the period, win rate, value, speed, overdue tasks
class SalesCrm::Reports::Agents < SalesCrm::Reports::Base
  def perform
    overdue = account.crm_tasks.open.where(due_at: ...Time.current).group(:assignee_id).count
    users.map { |u| row_for(u, overdue[u.id] || 0) }
  end

  private

  def users
    list = account.users.order(:name).to_a
    assignee_id ? list.select { |u| u.id == assignee_id } : list
  end

  def row_for(user, overdue_tasks)
    mine = deals.where(assignee_id: user.id)
    won = mine.won.where(won_at: range)
    won_count = won.count
    lost_count = mine.lost.where(lost_at: range).count
    { user_id: user.id, name: user.name, avatar_url: user.avatar_url, open_count: mine.open.count,
      won_count: won_count, lost_count: lost_count, win_rate: win_rate(won_count, lost_count),
      won_total_cents: won.sum(:amount_cents), avg_days_to_close: average_days_to_close(won), overdue_tasks: overdue_tasks }
  end
end
