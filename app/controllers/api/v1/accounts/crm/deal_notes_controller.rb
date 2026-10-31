# Custom (MyDesk): notes and the activity log of one deal
class Api::V1::Accounts::Crm::DealNotesController < Api::V1::Accounts::Crm::BaseController
  before_action :set_deal

  def index
    render json: @deal.notes.includes(:user).map { |n| SalesCrm::Presenter.note(n) }
  end

  def create
    note = ActiveRecord::Base.transaction do
      created = @deal.notes.create!(account: Current.account, user: Current.user, content: params.require(:content).to_s.strip)
      SalesCrm::ActivityLog.record(deal: @deal, kind: 'note_added', user: Current.user, data: { note_id: created.id })
      created
    end
    render json: SalesCrm::Presenter.note(note)
  end

  def destroy
    note = @deal.notes.find(params[:id])
    raise Pundit::NotAuthorizedError unless Current.account_user&.administrator? || note.user_id == Current.user.id

    note.destroy!
    head :ok
  end

  def activities
    render json: @deal.activities.includes(:user).limit(200).map { |a| SalesCrm::Presenter.activity(a) }
  end

  private

  def set_deal
    @deal = deals_scope.find(params[:deal_id])
    authorize @deal, :show?
  end
end
