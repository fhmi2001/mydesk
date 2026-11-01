# Custom (MyDesk): المؤشر 5, نسبة التحويل بين المراحل: of the deals that entered a stage, how many reached the next one.
# "Entered" comes from the activity log (creation plus every stage change, reopening included). A deal that skips a
# stage counts as having entered it (gap-analysis.md, question 8), so no rate ever goes above 100%.
module SalesCrm::Metrics::StageConversion
  module_function

  # stage_id => Set of deal ids that reached it, for the given deals of one pipeline
  def reached(account, pipeline, deal_ids)
    reached = Hash.new { |h, k| h[k] = Set.new }
    open_ids = pipeline.stages.select(&:open?).map(&:id)
    won_ids = pipeline.stages.select(&:won?).map(&:id)
    visited_by_deal(account, deal_ids).each do |deal_id, stage_ids|
      (stage_ids.to_a | passed_open_stages(stage_ids, open_ids, won_ids)).each { |stage_id| reached[stage_id] << deal_id }
    end
    reached
  end

  # The rate from one open stage's count to the next stage's
  def rate(count, previous_count)
    return nil if previous_count.nil?

    SalesCrm::Metrics::Ratio.percent(count, previous_count)
  end

  # The open stages up to the furthest one the deal reached (all of them once it was won)
  def passed_open_stages(stage_ids, open_ids, won_ids)
    return open_ids if stage_ids.intersect?(won_ids)

    furthest = stage_ids.filter_map { |id| open_ids.index(id) }.max
    furthest ? open_ids.first(furthest + 1) : []
  end

  # deal_id => ids of the stages it was created in or moved into
  def visited_by_deal(account, deal_ids)
    visited = Hash.new { |h, k| h[k] = Set.new }
    account.crm_activities.where(deal_id: deal_ids, kind: %w[created stage_changed reopened])
           .pluck(:deal_id, :kind, :data).each do |deal_id, kind, data|
      stage_id = kind == 'created' ? data['stage_id'] : data['to_stage_id']
      visited[deal_id] << stage_id.to_i if stage_id
    end
    visited
  end
end
