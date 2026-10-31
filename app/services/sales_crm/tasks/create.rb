# Custom (MyDesk): a new task, assigned to the acting user unless told otherwise; logged on its deal
class SalesCrm::Tasks::Create < SalesCrm::BaseService
  PERMITTED = %i[title description due_at assignee_id contact_id deal_id conversation_id].freeze

  def perform(params)
    params = params.to_h.symbolize_keys.slice(*PERMITTED)
    ActiveRecord::Base.transaction do
      deal = params[:deal_id].present? ? account.crm_deals.find(params[:deal_id]) : nil
      task = account.crm_tasks.create!(attributes(params, deal))
      log(deal, 'task_added', task_id: task.id, title: task.title) if deal
      broadcast('crm.task_created', id: task.id, assignee_id: task.assignee_id, deal_id: task.deal_id)
      task
    end
  end

  private

  def attributes(params, deal)
    { title: params[:title].to_s.strip, description: params[:description], due_at: params[:due_at].presence,
      assignee: assignee_for(params[:assignee_id]), creator: user, deal: deal,
      contact: params[:contact_id].present? ? account.contacts.find(params[:contact_id]) : deal&.contact,
      conversation: params[:conversation_id].present? ? account.conversations.find_by(display_id: params[:conversation_id]) : nil }
  end

  def assignee_for(id)
    id.present? ? account.users.find(id) : user
  end
end
