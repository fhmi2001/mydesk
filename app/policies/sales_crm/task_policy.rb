# Custom (MyDesk): tasks are visible to everyone in the account; only the creator or an administrator deletes one
class SalesCrm::TaskPolicy < ApplicationPolicy
  def index? = true
  def show? = true
  def create? = true
  def update? = true
  def complete? = true
  def reopen? = true
  def destroy? = account_user&.administrator? || record.creator_id == user.id

  class Scope < Scope
    def resolve
      account.crm_tasks
    end
  end
end
