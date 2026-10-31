# Custom (MyDesk): the account's lost reasons list. Everyone reads it (the "why was it lost" picker);
# administrators add, rename, reorder and delete. Deleting a reason keeps it on deals already lost with it.
class Api::V1::Accounts::Crm::LostReasonsController < Api::V1::Accounts::Crm::BaseController
  before_action :check_admin, except: [:index]
  before_action :ensure_defaults
  before_action :set_reason, only: [:update, :destroy]

  def index
    render json: reasons_json
  end

  def create
    Current.account.crm_lost_reasons.create!(name: params.require(:name),
                                             position: (Current.account.crm_lost_reasons.maximum(:position) || -1) + 1)
    render json: reasons_json
  end

  def update
    @reason.update!(name: params.require(:name))
    render json: reasons_json
  end

  def destroy
    @reason.destroy!
    render json: reasons_json
  end

  # ids: the reasons in their new order
  def reorder
    ids = Array(params.require(:ids)).map(&:to_i)
    ActiveRecord::Base.transaction do
      Current.account.crm_lost_reasons.where(id: ids).find_each { |reason| reason.update!(position: ids.index(reason.id)) }
    end
    render json: reasons_json
  end

  private

  def ensure_defaults
    SalesCrm::LostReason.ensure_defaults!(Current.account)
  end

  def check_admin
    raise Pundit::NotAuthorizedError unless Current.account_user&.administrator?
  end

  def set_reason
    @reason = Current.account.crm_lost_reasons.find(params[:id])
  end

  def reasons_json
    Current.account.crm_lost_reasons.reload.map { |r| { id: r.id, name: r.name, position: r.position } }
  end
end
