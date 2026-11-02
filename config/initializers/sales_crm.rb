# Custom (MyDesk): plugs the Sales CRM into Chatwoot's contact merge and agent removal flows without editing
# those files. Patches are prepended after the app has loaded them (to_prepare runs on every reload).
# The message listener (an employee's reply counts on the deal followed in that conversation) joins the async
# dispatcher the way config/initializers/smart_assistant.rb joins the sync one, after event_handlers.rb built it.
Rails.application.configure do
  config.to_prepare do
    ContactMergeAction.prepend(SalesCrm::ContactMergePatch) if defined?(SalesCrm::ContactMergePatch)
    Agents::DestroyJob.prepend(SalesCrm::AgentRemovalPatch) if defined?(SalesCrm::AgentRemovalPatch)
    Rails.configuration.dispatcher.async_dispatcher.subscribe(SalesCrm::MessageListener.instance)
  end
end
