# Custom (MyDesk): التقرير 9, التحويل بين المراحل: where do deals leak? Of the deals created in the period in one pipeline
# (the one filtered on, else the first), how many reached each stage, and what share went on to the next one
# (المؤشر 5, SalesCrm::Metrics::StageConversion: a skipped stage counts as entered). The stage losing the largest share
# is the leak. The team view puts each employee's rates beside the team's.
class SalesCrm::Reports::Conversion < SalesCrm::Reports::Report
  KEY = 'conversion'.freeze

  def self.list_filters = %i[product_id lead_source_id]

  def build
    return { empty: true, rows: [], assignees: nil } unless funnel_pipeline

    rows = stage_rows(reached)
    { pipeline_id: funnel_pipeline.id, pipeline_name: funnel_pipeline.name, created_count: created.count,
      empty: created.none?, rows: rows, leak_stage_id: leak(rows), assignees: assignee_rates(rows) }
  end

  # cell: stage_id, and assignee_id
  def drill_scope(cell)
    relation = by_assignee(created, cell)
    return relation if cell[:stage_id].blank?

    relation.where(id: reached(relation.select(:id))[cell[:stage_id].to_i].to_a)
  end

  private

  def funnel_pipeline
    @funnel_pipeline ||= pipeline || account.crm_pipelines.order(:position, :id).first
  end

  def created = deals.where(pipeline_id: funnel_pipeline.id, created_at: period.range)

  def reached(ids = created.select(:id))
    SalesCrm::Metrics::StageConversion.reached(account, funnel_pipeline, ids)
  end

  # The open stages then the won stage: [{ stage_id, name, color, kind, count, rate, dropped, cell }]
  def stage_rows(sets)
    previous = nil
    funnel_pipeline.stages.reject(&:lost?).map do |stage|
      count = sets[stage.id].size
      row = { stage_id: stage.id, name: stage.name, color: stage.color, kind: stage.kind, count: count,
              rate: SalesCrm::Metrics::StageConversion.rate(count, previous), dropped: previous && (previous - count),
              cell: { stage_id: stage.id } }
      previous = count
      row
    end
  end

  # The stage reached by the smallest share of the deals that reached the stage before it
  def leak(rows)
    rows.select { |r| r[:rate] && r[:rate] < 100 }.min_by { |r| r[:rate] }&.dig(:stage_id)
  end

  def assignee_rates(team_rows)
    return nil unless team_view?

    by_person = created.distinct.pluck(:assignee_id)
    people = names(by_person)
    by_person.map do |id|
      rows = stage_rows(reached(created.where(assignee_id: id).select(:id)))
      { assignee_id: id, name: people[id], created_count: created.where(assignee_id: id).count, cell: assignee_cell(id),
        stages: rows.zip(team_rows).map do |mine, team|
          { stage_id: mine[:stage_id], count: mine[:count], rate: mine[:rate], team_rate: team[:rate],
            cell: { stage_id: mine[:stage_id] }.merge(assignee_cell(id)) }
        end }
    end
  end
end
