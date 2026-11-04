# Custom (MyDesk): a deal note is deleted by its writer or an administrator (seeing the deal is checked first, by DealPolicy)
class SalesCrm::NotePolicy < ApplicationPolicy
  def destroy? = account_user&.administrator? || record.user_id == user.id
end
