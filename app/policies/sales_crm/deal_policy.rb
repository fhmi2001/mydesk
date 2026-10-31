# Custom (MyDesk): who may see and change deals. Administrators see everything; agents see every deal unless
# the account turns on "agents see only their own deals", and may delete only deals assigned to them.
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

  private

  def administrator?
    account_user&.administrator?
  end

  def own_only?
    !administrator? && ActiveModel::Type::Boolean.new.cast(account.crm_agents_see_own_deals_only) == true
  end

  def visible?
    return true unless own_only?

    record.assignee_id == user.id || (record.assignee_id.nil? && record.creator_id == user.id)
  end

  class Scope < Scope
    def resolve
      base = account.crm_deals.kept
      return base if account_user&.administrator? || ActiveModel::Type::Boolean.new.cast(account.crm_agents_see_own_deals_only) != true

      base.where(assignee_id: user.id).or(base.where(assignee_id: nil, creator_id: user.id))
    end
  end
end
