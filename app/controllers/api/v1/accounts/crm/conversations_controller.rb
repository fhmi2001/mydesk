# Custom (MyDesk): what the Sales section knows about one conversation (by its display id), for the new deal form and
# the conversation side panel (CONVERSATION_SALES_PLAN.md): the lead source mapped to its inbox (أ1), the pending
# suggestions the user may see (أ2), and a summary draft (أ3).
class Api::V1::Accounts::Crm::ConversationsController < Api::V1::Accounts::Crm::BaseController
  before_action :set_conversation

  def show
    render json: { lead_source_id: Current.account.crm_lead_source_for_inbox(@conversation.inbox_id)&.id,
                   suggestions: pending_suggestions(@conversation).map { |s| present_suggestion(s) },
                   linkable_deals: linkable_deals(@conversation),
                   ai_available: SmartAssistant::Config.configured? }
  end

  # A draft the employee edits before saving it as a note (أ3); nothing is written here
  def summary
    render json: SalesCrm::ConversationSummary.new(account: Current.account, conversation: @conversation).perform
  end

  private

  def set_conversation
    @conversation = Current.account.conversations.find_by!(display_id: params[:id])
  end

  def pending_suggestions(conversation)
    SalesCrm::Visibility.suggestions(Current.account, Current.user).pending.where(conversation_id: conversation.id)
                        .order(:created_at)
  end

  # The customer's open deals the user may see (their owner or an administrator) that are followed in another
  # conversation: the «اربطها» bar offers to follow them here (decision ح)
  def linkable_deals(conversation)
    return [] if conversation.contact_id.blank?

    deals_scope.kept.open.where(contact_id: conversation.contact_id).where.not(active_conversation_id: conversation.id)
               .or(deals_scope.kept.open.where(contact_id: conversation.contact_id, active_conversation_id: nil))
               .includes(:active_conversation).order(updated_at: :desc).limit(10)
               .map do |deal|
                 { id: deal.id, title: deal.title, active_conversation_display_id: deal.active_conversation&.display_id }
               end
  end

  def present_suggestion(suggestion)
    suggestion.slice(:id, :kind, :origin, :content, :deal_id, :created_at)
  end
end
