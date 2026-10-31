# Custom (MyDesk): puts a done task back to open; a past due date is not re-reminded
class SalesCrm::Tasks::Reopen < SalesCrm::BaseService
  def perform(task)
    return task if task.open?

    task.update!(status: :open, done_at: nil)
    broadcast('crm.task_updated', id: task.id, assignee_id: task.assignee_id, deal_id: task.deal_id)
    task
  end
end
