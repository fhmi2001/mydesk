# Custom (MyDesk): التقرير 11, دورة البيع والبقاء في المراحل (للمدير): how long a deal takes to close, and where it waits.
# The cycle is المؤشر 6 over the deals won in the period. The days in each open stage of the pipeline (the one filtered
# on, else the first) average the stays that ended in the period (SalesCrm::Metrics::StageStays): a deal that left the
# stage, by moving on or closing. Per employee and stage in the team view, as a heat map.
class SalesCrm::Reports::Cycle < SalesCrm::Reports::Report
  KEY = 'cycle'.freeze

  def self.admin_only? = true
  def self.list_filters = %i[product_id lead_source_id]

  def build
    return { empty: true, stages: [], assignees: nil } unless funnel_pipeline

    ended = ended_stays
    { pipeline_id: funnel_pipeline.id, pipeline_name: funnel_pipeline.name, cycle_days: SalesCrm::Metrics::SalesCycle.call(deals, period),
      previous_cycle_days: SalesCrm::Metrics::SalesCycle.call(deals, period.previous), won_count: won.count,
      approximate_count: ended.reject { |s| s[:logged] }.pluck(:deal_id).uniq.size,
      empty: ended.empty? && won.none?, stages: stage_rows(ended), assignees: assignee_rows_for(ended) }
  end

  # cell: stage_id (the deals whose stay there ended in the period) or none (the deals won); and assignee_id
  def drill_scope(cell)
    return by_assignee(won, cell) if cell[:stage_id].blank?

    ids = ended_stays.select { |s| s[:stage_id] == cell[:stage_id].to_i }.pluck(:deal_id)
    by_assignee(deals.where(id: ids), cell)
  end

  private

  def funnel_pipeline
    @funnel_pipeline ||= pipeline || account.crm_pipelines.order(:position, :id).first
  end

  def won = deals.won.where(won_at: period.range)

  def open_stages = funnel_pipeline.stages.select(&:open?)

  # [{ deal_id, assignee_id, stage_id, days, logged }] for the stays in open stages that ended in the period
  def ended_stays
    @ended_stays ||= begin
      candidates = deals.where(pipeline_id: funnel_pipeline.id, created_at: ..period.ends_at)
      owners = candidates.pluck(:id, :assignee_id).to_h
      open_ids = open_stages.map(&:id)
      SalesCrm::Metrics::StageStays.call(account, candidates).flat_map do |deal_id, history|
        history[:stays].select { |s| ended_here?(s, open_ids) }.map do |s|
          { deal_id: deal_id, assignee_id: owners[deal_id], stage_id: s.stage_id, days: s.days, logged: history[:logged] }
        end
      end
    end
  end

  def ended_here?(stay, open_ids) = stay.to.present? && period.range.cover?(stay.to) && open_ids.include?(stay.stage_id)

  def average_days(stays) = stays.empty? ? nil : (stays.sum { |s| s[:days] } / stays.size).round(1)

  def stage_rows(stays)
    open_stages.map do |stage|
      mine = stays.select { |s| s[:stage_id] == stage.id }
      { stage_id: stage.id, name: stage.name, color: stage.color, count: mine.size, average_days: average_days(mine),
        cell: { stage_id: stage.id } }
    end
  end

  def assignee_rows_for(stays)
    return nil unless team_view?

    ids = (stays.pluck(:assignee_id) + won.distinct.pluck(:assignee_id)).uniq
    people = names(ids)
    ids.map do |id|
      { assignee_id: id, name: people[id], cycle_days: SalesCrm::Metrics::SalesCycle.call(deals.where(assignee_id: id), period),
        cell: assignee_cell(id),
        stages: stage_rows(stays.select { |s| s[:assignee_id] == id }).each { |row| row[:cell] = row[:cell].merge(assignee_cell(id)) } }
    end
  end
end
