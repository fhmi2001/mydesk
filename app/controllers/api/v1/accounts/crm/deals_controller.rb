# Custom (MyDesk): deals: the board / table, one deal, create, edit, move, reopen, delete, restore, forecast
class Api::V1::Accounts::Crm::DealsController < Api::V1::Accounts::Crm::BaseController
  before_action :set_pipeline, only: [:index, :forecast]
  before_action :set_deal, only: [:show, :update, :move, :reopen, :destroy]

  def index
    result = service(SalesCrm::Deals::Search).perform(deals_scope, pipeline: @pipeline, **search_filters)
    render json: { deals: present_deals(result[:deals]), counts: visible_counts(result[:counts]), total: result[:total],
                   page: result[:page], per_stage_limit: SalesCrm::Deals::Search::BOARD_PER_STAGE }
  end

  def discarded
    authorize SalesCrm::Deal, :restore?
    deals = Current.account.crm_deals.discarded.includes(:contact, :assignee, :stage).order(discarded_at: :desc)
                   .page(params[:page].to_i.clamp(1, 10_000)).per(50)
    render json: { deals: present_deals(deals), total: deals.total_count }
  end

  def forecast
    render json: SalesCrm::Presenter.forecast(SalesCrm::Forecast.call(forecast_scope, pipeline: @pipeline))
  end

  def show
    authorize @deal
    render json: SalesCrm::Presenter.deal(@deal)
  end

  def create
    authorize SalesCrm::Deal
    deal = service(SalesCrm::Deals::Create).perform(deal_params)
    render json: SalesCrm::Presenter.deal(deal)
  end

  def update
    authorize @deal
    render json: SalesCrm::Presenter.deal(service(SalesCrm::Deals::Update).perform(@deal, deal_params))
  end

  def move
    authorize @deal
    deal = service(SalesCrm::Deals::Move).perform(@deal, stage_id: params.require(:stage_id), position: params[:position],
                                                         lost_reason: params[:lost_reason], lost_note: params[:lost_note],
                                                         lock_version: params[:lock_version])
    render json: SalesCrm::Presenter.deal(deal)
  end

  def reopen
    authorize @deal
    render json: SalesCrm::Presenter.deal(service(SalesCrm::Deals::Reopen).perform(@deal))
  end

  def destroy
    authorize @deal
    service(SalesCrm::Deals::Discard).perform(@deal)
    head :ok
  end

  def restore
    deal = Current.account.crm_deals.discarded.find(params[:id])
    authorize deal
    render json: SalesCrm::Presenter.deal(service(SalesCrm::Deals::Restore).perform(deal))
  end

  private

  def set_pipeline
    @pipeline = if params[:pipeline_id].present?
                  Current.account.crm_pipelines.find(params[:pipeline_id])
                else
                  SalesCrm::Pipelines::EnsureDefault.call(Current.account)
                end
  end

  def set_deal
    @deal = deals_scope.find(params[:id])
  end

  # Team money is for administrators. An agent may see the whole team's deals (when "own deals only" is off), but
  # not their sums: the board's column totals are dropped, and the forecast only ever covers the agent's own deals.
  def team_money?
    Current.account_user&.administrator?
  end

  def visible_counts(counts)
    return counts if team_money? || own_deals_only?

    counts.transform_values { |c| c.except(:total_cents, :weighted_cents) }
  end

  def own_deals_only?
    ActiveModel::Type::Boolean.new.cast(Current.account.crm_agents_see_own_deals_only) == true
  end

  def forecast_scope
    return deals_scope.where(assignee_id: Current.user.id) unless team_money?

    params[:assignee_id].present? ? deals_scope.where(assignee_id: params[:assignee_id]) : deals_scope
  end

  def search_filters
    { stage_id: params[:stage_id], assignee_id: params[:assignee_id], status: params[:status], priority: params[:priority],
      q: params[:q], view: params[:view].presence || :board, page: params[:page].presence || 1, sort: params[:sort] }
  end

  def deal_params
    params.require(:deal).permit(:title, :amount, :pipeline_id, :stage_id, :contact_id, :assignee_id, :close_date, :description,
                                 :conversation_id, :priority, :forecast_category, :probability_override, :lock_version,
                                 *SalesCrm::ListItem::DEAL_COLUMNS.values)
  end
end
