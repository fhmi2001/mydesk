json.id resource.display_id
json.title resource.title
json.description resource.description
json.account_id resource.account_id
json.inbox do
  json.partial! 'api/v1/models/inbox', formats: [:json], resource: resource.inbox
end
json.sender do
  json.partial! 'api/v1/models/agent', formats: [:json], resource: resource.sender if resource.sender.present?
end
json.message resource.message
json.template_params resource.template_params
json.campaign_status resource.campaign_status
json.enabled resource.enabled
json.campaign_type resource.campaign_type
if resource.campaign_type == 'one_off'
  json.scheduled_at resource.scheduled_at.to_i
  json.started_at resource.started_at&.to_i
  json.completed_at resource.completed_at&.to_i
  json.audience resource.audience
  json.sms_sender_name resource.sms_sender_name
  json.sms_stats resource.sms_delivery_stats if resource.sms_campaign?
end
# Custom (MyDesk): how often a live chat campaign has started a conversation with a visitor
if resource.ongoing?
  json.conversations_count resource.conversations.count
  json.last_conversation_at resource.conversations.maximum(:created_at)&.to_i
end
json.trigger_rules resource.trigger_rules
json.trigger_only_during_business_hours resource.trigger_only_during_business_hours
json.created_at resource.created_at
json.updated_at resource.updated_at
