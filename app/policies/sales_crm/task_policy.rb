# Custom (MyDesk): which tasks someone sees comes from SalesCrm::Visibility; only the creator or an administrator deletes one
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
      SalesCrm::Visibility.tasks(account, user)
    end
  end
end
