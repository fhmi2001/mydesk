# Custom (MyDesk): deletes a task
class SalesCrm::Tasks::Destroy < SalesCrm::BaseService
  def perform(task)
    payload = { id: task.id, assignee_id: task.assignee_id, deal_id: task.deal_id }
    audience = task_audience(task)
    task.destroy!
    broadcast('crm.task_destroyed', payload, to: audience)
    task
  end
end
