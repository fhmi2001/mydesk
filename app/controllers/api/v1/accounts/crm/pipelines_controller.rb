# Custom (MyDesk): pipelines and their stages; writing is for administrators
class Api::V1::Accounts::Crm::PipelinesController < Api::V1::Accounts::Crm::BaseController
  before_action :set_pipeline, only: [:update, :destroy]

  def index
    SalesCrm::Pipelines::EnsureDefault.call(Current.account)
    counts = Current.account.crm_deals.kept.group(:pipeline_id).count
    render json: Current.account.crm_pipelines.includes(:stages).map { |p| SalesCrm::Presenter.pipeline(p, deals_count: counts[p.id] || 0) }
  end

  def create
    authorize SalesCrm::Pipeline
    pipeline = service(SalesCrm::Pipelines::Create).perform(name: params.require(:name), currency: params[:currency], stages: stage_params)
    render json: SalesCrm::Presenter.pipeline(pipeline, deals_count: 0)
  end

  def update
    authorize @pipeline
    pipeline = service(SalesCrm::Pipelines::Update).perform(@pipeline, name: params[:name],
                                                                       stages: stage_params, stage_moves: params[:stage_moves]&.to_unsafe_h || {})
    render json: SalesCrm::Presenter.pipeline(pipeline, deals_count: Current.account.crm_deals.kept.where(pipeline_id: pipeline.id).count)
  end

  def destroy
    authorize @pipeline
    service(SalesCrm::Pipelines::Destroy).perform(@pipeline)
    head :ok
  end

  private

  def set_pipeline
    @pipeline = Current.account.crm_pipelines.find(params[:id])
  end

  def stage_params
    return nil unless params.key?(:stages)

    params.require(:stages).map { |s| s.permit(:id, :name, :probability, :kind, :color).to_h }
  end
end
