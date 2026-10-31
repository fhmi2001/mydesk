# Custom (MyDesk): prepended into Agents::DestroyJob so an agent removed from an account leaves their open
# deals and tasks unassigned (administrators then reassign them from the "no assignee" filter).
module SalesCrm::AgentRemovalPatch
  def unassign_conversations(account, user)
    super
    SalesCrm::Deal.where(account_id: account.id, assignee_id: user.id, status: :open).update_all(assignee_id: nil) # rubocop:disable Rails/SkipsModelValidations
    SalesCrm::Task.where(account_id: account.id, assignee_id: user.id, status: :open).update_all(assignee_id: nil) # rubocop:disable Rails/SkipsModelValidations
  end
end
