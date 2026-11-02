# Custom (MyDesk): plugs the Sales CRM into Chatwoot's contact merge and agent removal flows without editing
# those files. Patches are prepended after the app has loaded them (to_prepare runs on every reload).
Rails.application.configure do
  config.to_prepare do
    ContactMergeAction.prepend(SalesCrm::ContactMergePatch) if defined?(SalesCrm::ContactMergePatch)
    Agents::DestroyJob.prepend(SalesCrm::AgentRemovalPatch) if defined?(SalesCrm::AgentRemovalPatch)
  end
end
