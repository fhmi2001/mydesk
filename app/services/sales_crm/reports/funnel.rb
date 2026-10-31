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

  # stage_id => set of deal ids that were created in or moved into that stage
  def reached_by_stage(pipeline)
    deal_ids = deals.where(pipeline_id: pipeline.id, created_at: range).select(:id)
    reached = Hash.new { |h, k| h[k] = Set.new }
    account.crm_activities.where(deal_id: deal_ids, kind: %w[created stage_changed reopened]).pluck(:deal_id, :kind,
                                                                                                    :data).each do |deal_id, kind, data|
      stage_id = kind == 'created' ? data['stage_id'] : data['to_stage_id']
      reached[stage_id.to_i] << deal_id if stage_id
    end
    reached
  end

  def conversion(count, previous)
    return nil if previous.nil? || previous.zero?

    (count * 100.0 / previous).round(1)
  end
end
