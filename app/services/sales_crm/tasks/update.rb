# Custom (MyDesk): edits a task; moving the due date later re-arms its reminder
class SalesCrm::Tasks::Update < SalesCrm::BaseService
  PERMITTED = %i[title description due_at assignee_id contact_id deal_id kind].freeze

  def perform(task, params)
    params = params.to_h.symbolize_keys.slice(*PERMITTED)
    ActiveRecord::Base.transaction do
      assign_text(task, params)
      assign_due(task, params[:due_at]) if params.key?(:due_at)
      assign_links(task, params)
      task.save!
      broadcast('crm.task_updated', id: task.id, assignee_id: task.assignee_id, deal_id: task.deal_id)
      task
    end
  end

  private

  def assign_text(task, params)
    task.title = params[:title].to_s.strip if params.key?(:title)
    task.description = params[:description] if params.key?(:description)
    task.kind = task_kind_from(params[:kind]) if params[:kind].present?
  end

  def assign_due(task, value)
    new_due = value.presence
    task.reminded_at = nil if new_due && (task.due_at.nil? || new_due.to_time > task.due_at)
    task.due_at = new_due
  end

  def assign_links(task, params)
    task.assignee = params[:assignee_id].present? ? account.users.find(params[:assignee_id]) : nil if params.key?(:assignee_id)
    task.contact = params[:contact_id].present? ? account.contacts.find(params[:contact_id]) : nil if params.key?(:contact_id)
    task.deal = params[:deal_id].present? ? account.crm_deals.find(params[:deal_id]) : nil if params.key?(:deal_id)
  end
end
