# Custom (MyDesk): who may see and change deals (SalesCrm::Visibility): administrators see and change everything;
# an employee sees, edits and deletes only the deals they own, and only an administrator hands a deal to someone else.
class SalesCrm::DealPolicy < ApplicationPolicy
  def index? = true
  def show? = visible?
  def create? = true
  def update? = visible?
  def move? = visible?
  def reopen? = visible?
  def restore? = administrator?
  def destroy? = administrator? || record.assignee_id == user.id
  def forecast? = true
  def reassign? = administrator?

  private

  def administrator?
    account_user&.administrator?
  end

  def visible?
    administrator? || record.assignee_id == user.id
  end

  class Scope < Scope
    def resolve
      SalesCrm::Visibility.deals(account, user)
    end
  end
end
