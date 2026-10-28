# Custom (MyDesk): plug the smart assistant and the WhatsApp Web send-failure recovery into Chatwoot's event
# dispatcher without editing its listener lists. Runs after event_handlers.rb has built the dispatcher
# (initializers load in alphabetical order). Both listeners are light (lookups, enqueues), so they run sync
# and a reply starts without waiting for the async event job.
Rails.application.configure do
  config.to_prepare do
    Rails.configuration.dispatcher.sync_dispatcher.subscribe(SmartAssistantListener.instance)
    Rails.configuration.dispatcher.sync_dispatcher.subscribe(WhatsappWebSendFailureListener.instance)
  end
end
