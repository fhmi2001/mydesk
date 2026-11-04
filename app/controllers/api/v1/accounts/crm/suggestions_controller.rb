# Custom (MyDesk): the suggestions the user may see (CONVERSATION_SALES_PLAN.md). Any can be dismissed. A «صفقة جديدة» is
# accepted when the deal is created from it (SalesCrm::Deals::Create); a deal's follow-up, won or lost message gets its
# draft on request and is accepted when the employee takes the draft to send it themselves.
class Api::V1::Accounts::Crm::SuggestionsController < Api::V1::Accounts::Crm::BaseController
  before_action :set_suggestion

  def dismiss
    @suggestion.decide!(:dismissed, Current.user)
    render json: SalesCrm::Presenter.suggestion(@suggestion)
  end

  def draft
    raise ActiveRecord::RecordNotFound unless deal_kind?

    text = SalesCrm::MessageDraft.new(account: Current.account, suggestion: @suggestion).perform
    render json: { draft: text, can_reply: conversation_open_for_text? }
  end

  def accept
    raise ActiveRecord::RecordNotFound unless deal_kind?

    @suggestion.decide!(:accepted, Current.user)
    render json: SalesCrm::Presenter.suggestion(@suggestion)
  end

  private

  def set_suggestion
    @suggestion = SalesCrm::Visibility.suggestions(Current.account, Current.user).pending.find(params[:id])
  end

  def deal_kind? = SalesCrm::Suggestion::DEAL_KINDS.include?(@suggestion.kind)

  # Official WhatsApp past its 24-hour window takes templates only (Conversation#can_reply?)
  def conversation_open_for_text?
    conversation = @suggestion.deal&.active_conversation || @suggestion.conversation
    conversation.nil? || conversation.can_reply?
  end
end
