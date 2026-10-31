# Custom (MyDesk): marks a task done (idempotent) and notes it on the deal
class SalesCrm::Tasks::Complete < SalesCrm::BaseService
  def perform(task)
    return task if task.done?

    ActiveRecord::Base.transaction do
      task.update!(status: :done, done_at: Time.current)
      log(task.deal, 'task_done', task_id: task.id, title: task.title) if task.deal
      broadcast('crm.task_completed', { id: task.id, assignee_id: task.assignee_id, deal_id: task.deal_id }, to: task_audience(task))
      task
    end
  end
end
