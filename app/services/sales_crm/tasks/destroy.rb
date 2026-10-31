# Custom (MyDesk): deletes a task
class SalesCrm::Tasks::Destroy < SalesCrm::BaseService
  def perform(task)
    payload = { id: task.id, assignee_id: task.assignee_id, deal_id: task.deal_id }
    task.destroy!
    broadcast('crm.task_destroyed', payload)
    task
  end
end
