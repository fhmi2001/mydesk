# Custom (MyDesk): التقرير 14, نشاط الفريق (للمدير فقط): does each employee's activity match their results? The activity
# of the period is the tasks they completed, by kind (call, meeting, task), and the notes they wrote on deals; Chatwoot
# conversations do not count (phase 1). Beside it, what they won and their win rate. Compared with the period before.
class SalesCrm::Reports::Activity < SalesCrm::Reports::Report
  KEY = 'activity'.freeze
  KINDS = SalesCrm::Task.kinds.keys.freeze

  def self.admin_only? = true

  def build
    rows = people_rows
    { totals: sum_rows(rows), previous_totals: sum_rows(people_rows(period.previous)), kinds: KINDS,
      empty: rows.all? { |r| r[:activity_count].zero? && r[:won_count].zero? }, assignees: rows }
  end

  # cell: kind (call, meeting or task: the tasks completed) or none for the deals won; and assignee_id
  def drill(page: 1)
    return super unless KINDS.include?(cell[:kind].to_s)

    relation = tasks_for(cell)
    { type: 'tasks', total_count: relation.count,
      items: relation.includes(:assignee, :contact, :deal, :conversation).order(done_at: :desc, id: :desc)
                     .page(page.to_i.clamp(1, 10_000)).per(PER_PAGE).map { |task| SalesCrm::Presenter.task(task) } }
  end

  def drill_scope(cell) = by_assignee(deals.won.where(won_at: period.range), cell)

  private

  def done_tasks(window = period) = account.crm_tasks.done.where(done_at: window.range)
  def notes(window = period) = account.crm_notes.where(created_at: window.range)

  def tasks_for(cell)
    relation = done_tasks.where(kind: cell[:kind].to_s)
    relation = relation.where(assignee_id: cell[:assignee_id].to_s == NONE ? nil : cell[:assignee_id].to_i) if cell.key?(:assignee_id)
    assignee_id ? relation.where(assignee_id: assignee_id) : relation
  end

  # One row per employee with activity or results in the window (the filtered one when an employee is picked)
  def people_rows(window = period)
    tasks = done_tasks(window).group(:assignee_id, :kind).count
    notes_by = notes(window).group(:user_id).count
    ids = people_ids(tasks.keys.map(&:first) + notes_by.keys, window)
    people = names(ids)
    ids.map { |id| person_row(id, people[id], tasks, notes_by.fetch(id, 0), window) }.sort_by { |r| -r[:activity_count] }
  end

  def people_ids(active, window)
    won = SalesCrm::Visibility.deals(account, user).won.where(won_at: window.range)
    ids = (active + won.distinct.pluck(:assignee_id)).compact.uniq
    assignee_id ? ids & [assignee_id.to_i] : ids
  end

  def person_row(id, name, tasks, note_count, window)
    by_kind = KINDS.index_with { |kind| tasks.fetch([id, kind], 0) }
    results = SalesCrm::Metrics::WinRate.call(deals.where(assignee_id: id), window)
    { assignee_id: id, name: name, by_kind: by_kind, note_count: note_count, activity_count: by_kind.values.sum + note_count,
      won_count: results[:won_count], won_cents: results[:won_cents], win_rate: results[:by_count], cell: assignee_cell(id) }
  end

  def sum_rows(rows)
    { by_kind: KINDS.index_with { |kind| rows.sum { |r| r[:by_kind][kind] } }, note_count: rows.sum { |r| r[:note_count] },
      activity_count: rows.sum { |r| r[:activity_count] }, won_count: rows.sum { |r| r[:won_count] },
      won_cents: rows.sum { |r| r[:won_cents] } }
  end
end
