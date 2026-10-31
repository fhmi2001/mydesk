# Custom (MyDesk): how many deals created in the period reached each stage of the pipeline (from the
# activity log: creation plus every stage change), and the drop between consecutive open stages.
class SalesCrm::Reports::Funnel < SalesCrm::Reports::Base
  def perform
    pipeline = self.pipeline || account.crm_pipelines.first
    return [] unless pipeline

    reached = reached_by_stage(pipeline)
    previous = nil
    pipeline.stages.map do |stage|
      count = reached[stage.id].size
      row = { stage_id: stage.id, name: stage.name, kind: stage.kind, color: stage.color, reached_count: count,
              conversion_from_previous: conversion(count, previous) }
      previous = count if stage.open?
      row
    end
  end

  private

  # stage_id => set of deal ids that reached that stage. A set, so a deal that comes back to a stage counts
  # once. Reaching an open stage, or won, also counts as passing every open stage before it, so a deal moved
  # straight from the first stage to won still counts in the stages in between and the funnel never rises.
  def reached_by_stage(pipeline)
    reached = Hash.new { |h, k| h[k] = Set.new }
    open_ids = pipeline.stages.select(&:open?).map(&:id)
    won_ids = pipeline.stages.select(&:won?).map(&:id)
    visited_by_deal(pipeline).each do |deal_id, stage_ids|
      (stage_ids.to_a | passed_open_stages(stage_ids, open_ids, won_ids)).each { |stage_id| reached[stage_id] << deal_id }
    end
    reached
  end

  # The open stages up to the furthest one the deal reached (all of them once it was won)
  def passed_open_stages(stage_ids, open_ids, won_ids)
    return open_ids if stage_ids.intersect?(won_ids)

    furthest = stage_ids.filter_map { |id| open_ids.index(id) }.max
    furthest ? open_ids.first(furthest + 1) : []
  end

  # deal_id => ids of the stages it was created in or moved into, from the activity log
  def visited_by_deal(pipeline)
    deal_ids = deals.where(pipeline_id: pipeline.id, created_at: range).select(:id)
    visited = Hash.new { |h, k| h[k] = Set.new }
    account.crm_activities.where(deal_id: deal_ids, kind: %w[created stage_changed reopened])
           .pluck(:deal_id, :kind, :data).each do |deal_id, kind, data|
      stage_id = kind == 'created' ? data['stage_id'] : data['to_stage_id']
      visited[deal_id] << stage_id.to_i if stage_id
    end
    visited
  end

  def conversion(count, previous)
    return nil if previous.nil? || previous.zero?

    (count * 100.0 / previous).round(1)
  end
end
