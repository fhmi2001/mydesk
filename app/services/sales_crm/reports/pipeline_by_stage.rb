# Custom (MyDesk): التقرير 1, خط الأنابيب حسب المرحلة: how many open deals, worth what, sit in each stage, and their
# weighted value (المؤشر 1). A picture of now, so it takes no period and has no previous period to compare with. The
# team view splits each stage by employee and adds a total per employee.
class SalesCrm::Reports::PipelineByStage < SalesCrm::Reports::Report
  KEY = 'pipeline_by_stage'.freeze

  def self.list_filters = %i[product_id lead_source_id]

  def build
    by_stage = groups.group_by { |g| g[:stage_id] }
    totals = sum(groups)
    { totals: totals, empty: totals[:count].zero?,
      rows: stages.map { |stage| stage_row(stage, by_stage.fetch(stage.id, [])) },
      assignees: assignee_rows(groups) }
  end

  def drill_scope(cell)
    relation = base
    relation = relation.where(stage_id: cell[:stage_id].to_i) if cell[:stage_id].present?
    by_assignee(relation, cell)
  end

  private

  def base = deals.open

  def groups
    @groups ||= grouped(base, stage_id: 'crm_deals.stage_id', assignee_id: 'crm_deals.assignee_id')
  end

  # The open stages of the pipeline filtered on, else of every pipeline, in board order
  def stages
    relation = account.crm_stages.where(kind: :open).includes(:pipeline)
    relation = relation.where(pipeline_id: pipeline.id) if pipeline
    relation.joins(:pipeline).order('crm_pipelines.position, crm_stages.position')
  end

  def stage_row(stage, rows)
    cell = { stage_id: stage.id }
    sum(rows).merge(stage_id: stage.id, name: stage.name, color: stage.color, probability: stage.probability,
                    pipeline_id: stage.pipeline_id, pipeline_name: stage.pipeline.name, cell: cell,
                    assignees: assignee_rows(rows, cell))
  end
end
