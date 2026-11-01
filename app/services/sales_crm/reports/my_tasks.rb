# Custom (MyDesk): التقرير 4, مهامي ومتابعاتي: what is asked of me today and what is late. Always the signed-in user's own
# open tasks, administrators included (the matrix gives the manager no team view of it). Overdue: due before now. Due
# today: due between now and the end of the day in Riyadh. Done: completed in the period, compared with the one before.
class SalesCrm::Reports::MyTasks < SalesCrm::Reports::Report
  KEY = 'my_tasks'.freeze
  KINDS = %w[overdue today done].freeze

  def initialize(account:, user:, **filters)
    super
    @now = filters[:now] || Time.current
  end

  def build
    { totals: totals, previous_totals: { done_count: done(period.previous).count },
      empty: open_rows.empty? && totals[:done_count].zero?, rows: open_rows.map { |task| SalesCrm::Presenter.task(task, now: @now) } }
  end

  # cell: kind (overdue, today or done) and task_kind (task, call or meeting)
  def drill(page: 1)
    relation = kind_scope(KINDS.include?(cell[:kind].to_s) ? cell[:kind].to_s : 'overdue')
    relation = relation.where(kind: cell[:task_kind].to_s) if SalesCrm::Task.kinds.key?(cell[:task_kind].to_s)
    { total_count: relation.count,
      items: relation.includes(:assignee, :contact, :deal, :conversation).page(page.to_i.clamp(1, 10_000)).per(PER_PAGE)
                     .map { |task| SalesCrm::Presenter.task(task, now: @now) } }
  end

  private

  def team_view? = false

  def tasks = account.crm_tasks.where(assignee_id: user.id)

  def kind_scope(kind)
    case kind
    when 'overdue' then tasks.open.where(due_at: ...@now).order(:due_at, :id)
    when 'today' then tasks.open.where(due_at: @now..SalesCrm::TimeZone.today_range(account, @now).end).order(:due_at, :id)
    else done(period).order(done_at: :desc, id: :desc)
    end
  end

  def done(window) = tasks.done.where(done_at: window.range)

  def totals
    @totals ||= { overdue_count: kind_scope('overdue').count, today_count: kind_scope('today').count, done_count: done(period).count,
                  by_kind: SalesCrm::Task.kinds.keys.index_with(0).merge(due_by_today.group(:kind).count) }
  end

  # Overdue and due today together
  def due_by_today = tasks.open.where(due_at: ..SalesCrm::TimeZone.today_range(account, @now).end)

  def open_rows
    @open_rows ||= kind_scope('overdue').includes(:assignee, :contact, :deal, :conversation).limit(@list_limit).to_a +
                   kind_scope('today').includes(:assignee, :contact, :deal, :conversation).limit(@list_limit).to_a
  end
end
