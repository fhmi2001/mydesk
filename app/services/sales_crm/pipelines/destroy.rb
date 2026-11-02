# Custom (MyDesk): removes an empty pipeline; the last pipeline and pipelines with deals stay
class SalesCrm::Pipelines::Destroy < SalesCrm::BaseService
  def perform(pipeline)
    fail!(:last_pipeline) if account.crm_pipelines.where.not(id: pipeline.id).none?
    fail!(:pipeline_has_deals) if account.crm_deals.exists?(pipeline_id: pipeline.id)

    pipeline.destroy!
  end
end
