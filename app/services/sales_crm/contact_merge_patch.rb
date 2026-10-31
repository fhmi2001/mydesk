# Custom (MyDesk): prepended into ContactMergeAction (config/initializers/sales_crm.rb) so merging two contacts
# also moves the deals and tasks of the removed contact to the one that stays.
module SalesCrm::ContactMergePatch
  def merge_conversations
    super
    SalesCrm::Deal.where(contact_id: @mergee_contact.id, account_id: @account.id)
                  .update_all(contact_id: @base_contact.id, contact_name_snapshot: @base_contact.name) # rubocop:disable Rails/SkipsModelValidations
    SalesCrm::Task.where(contact_id: @mergee_contact.id, account_id: @account.id).update_all(contact_id: @base_contact.id) # rubocop:disable Rails/SkipsModelValidations
  end
end
