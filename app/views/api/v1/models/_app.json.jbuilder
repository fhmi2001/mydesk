json.id resource.id
json.name resource.name
json.description resource.description
json.short_description resource.short_description.presence
cleanup_only = resource.id == 'stripe' && !resource.active?(@current_account)
# Custom (MyDesk): the smart assistant keeps its own settings table instead of an integration hook
enabled = resource.id == 'smart_assistant' ? SmartAssistant.exists?(account: @current_account, enabled: true) : resource.enabled?(@current_account)
json.enabled !cleanup_only && enabled
json.cleanup_only cleanup_only if resource.id == 'stripe'
# Custom (MyDesk): Salla is always listed; this tells the page whether the MyDesk Salla app keys are set yet
json.configured Salla::Config.configured? if resource.id == 'salla'

if Current.account_user&.administrator?
  json.call(resource.params, *resource.params.keys)
  json.action resource.action
  json.button resource.action
end

json.hooks do
  json.array! @current_account.hooks.where(app_id: resource.id) do |hook|
    json.partial! 'api/v1/models/hook', formats: [:json], resource: hook
  end
end
