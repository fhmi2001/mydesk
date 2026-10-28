# Custom (MyDesk): plug the smart assistant into Chatwoot's event
# dispatcher without editing its listener lists. Runs after event_handlers.rb has built the dispatcher
# (initializers load in alphabetical order). The listener is light (lookups, enqueues), so it runs sync
# and a reply starts without waiting for the async event job.
Rails.application.configure do
  config.to_prepare do
    Rails.configuration.dispatcher.sync_dispatcher.subscribe(SmartAssistantListener.instance)
  end
end
