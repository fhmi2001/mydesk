# Custom (MyDesk): a conversation's latest public messages with text, oldest first: what the assistant replies to
# and what the Sales section's AI drafts read
module SmartAssistant::Transcript
  module_function

  def recent(conversation, limit)
    conversation.messages.where(message_type: %i[incoming outgoing], private: false).where.not(content: [nil, ''])
                .reorder(id: :desc).limit(limit).to_a.reverse
  end
end
