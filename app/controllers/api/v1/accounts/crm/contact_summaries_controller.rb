# Custom (MyDesk): a contact's open deals and upcoming tasks, for the conversation and contact side panels
class Api::V1::Accounts::Crm::ContactSummariesController < Api::V1::Accounts::Crm::BaseController
  LIMIT = 20

  def show
    contact = Current.account.contacts.find(params[:contact_id])
    render json: { deals: present_deals(open_deals(contact)), tasks: open_tasks(contact).map { |t| SalesCrm::Presenter.task(t) },
                   closed_count: deals_scope.where(contact_id: contact.id).where.not(status: :open).count }
  end

  private

  def open_deals(contact)
    deals_scope.open.where(contact_id: contact.id).includes(:assignee, :stage, :conversation).order(updated_at: :desc).limit(LIMIT)
  end

  def open_tasks(contact)
    tasks_scope.open.where(contact_id: contact.id).includes(:assignee, :deal, :conversation).order(Arel.sql('due_at ASC NULLS LAST')).limit(LIMIT)
  end
end
