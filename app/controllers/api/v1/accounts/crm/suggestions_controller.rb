# Custom (MyDesk): the employee dismisses a suggestion they may see (CONVERSATION_SALES_PLAN.md). Accepting one is
# done by what it suggests: a «صفقة جديدة» is accepted when the deal is created from it (SalesCrm::Deals::Create).
class Api::V1::Accounts::Crm::SuggestionsController < Api::V1::Accounts::Crm::BaseController
  def dismiss
    suggestion = SalesCrm::Visibility.suggestions(Current.account, Current.user).pending.find(params[:id])
    suggestion.decide!(:dismissed, Current.user)
    render json: suggestion.slice(:id, :kind, :status)
  end
end
