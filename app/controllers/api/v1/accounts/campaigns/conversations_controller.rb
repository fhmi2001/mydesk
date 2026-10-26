# Custom (MyDesk): the conversations a campaign started (a live chat campaign opens one per visitor it reaches),
# newest first, page by page, for the campaign details page.
class Api::V1::Accounts::Campaigns::ConversationsController < Api::V1::Accounts::BaseController
  PER_PAGE = 25

  def index
    campaign = Current.account.campaigns.find_by!(display_id: params[:campaign_id])
    authorize campaign, :show?

    conversations = campaign.conversations.includes(:contact, :assignee).order(created_at: :desc)
    page = [params[:page].to_i, 1].max

    render json: {
      meta: { count: conversations.count, page: page, per_page: PER_PAGE },
      payload: conversations.offset((page - 1) * PER_PAGE).limit(PER_PAGE).map { |conversation| conversation_json(conversation) }
    }
  end

  private

  def conversation_json(conversation)
    {
      id: conversation.display_id,
      status: conversation.status,
      created_at: conversation.created_at.to_i,
      last_activity_at: conversation.last_activity_at&.to_i,
      contact: conversation.contact&.slice(:id, :name, :email, :phone_number),
      assignee: conversation.assignee&.slice(:id, :name)
    }
  end
end
