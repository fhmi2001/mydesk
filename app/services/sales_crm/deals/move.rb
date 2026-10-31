# Custom (MyDesk): moves a deal to a stage and position. Landing on the lost stage needs a reason; landing on
# won/lost sets the status and timestamps. `position` is 1-based among the stage's live deals; the whole
# stage is renumbered densely so positions always match what the board shows.
class SalesCrm::Deals::Move < SalesCrm::BaseService
  def perform(deal, stage_id:, position: nil, lost_reason: nil, lock_version: nil)
    stage = find_stage!(deal.pipeline, stage_id)
    fail!(:lost_reason_required) if stage.lost? && lost_reason.to_s.strip.blank?

    ActiveRecord::Base.transaction do
      from_stage_id = deal.stage_id
      deal.lock_version = lock_version.to_i unless lock_version.nil?
      place(deal, stage, position)
      apply_status(deal, stage, lost_reason)
      deal.save!
      log_move(deal, stage, from_stage_id)
      broadcast('crm.deal_moved', id: deal.id, stage_id: stage.id, position: deal.position, pipeline_id: deal.pipeline_id,
                                  from_stage_id: from_stage_id)
      deal
    end
  end

  private

  def place(deal, stage, position)
    ids = account.crm_deals.kept.where(stage_id: stage.id).where.not(id: deal.id).order(:position, id: :desc).pluck(:id)
    index = position.nil? ? ids.size : (position.to_i - 1).clamp(0, ids.size)
    ids.insert(index, deal.id)
    renumber(ids, deal.id)
    deal.stage = stage
    deal.position = index + 1
  end

  # One UPDATE for the siblings; the moved deal gets its position through save!
  def renumber(ids, moved_id)
    others = ids.each_with_index.reject { |id, _| id == moved_id }
    return if others.empty?

    cases = others.map { |id, i| "WHEN #{id.to_i} THEN #{i + 1}" }.join(' ')
    SalesCrm::Deal.where(id: others.map(&:first)).update_all(Arel.sql("position = CASE id #{cases} END")) # rubocop:disable Rails/SkipsModelValidations
  end

  def apply_status(deal, stage, lost_reason)
    case stage.kind
    when 'won'
      deal.assign_attributes(status: :won, won_at: deal.won_at || Time.current, lost_at: nil, lost_reason: nil)
    when 'lost'
      deal.assign_attributes(status: :lost, lost_at: deal.lost_at || Time.current, won_at: nil, lost_reason: lost_reason.to_s.strip)
    else
      deal.assign_attributes(status: :open, won_at: nil, lost_at: nil, lost_reason: nil)
    end
  end

  def log_move(deal, stage, from_stage_id)
    return if from_stage_id == stage.id

    log(deal, 'stage_changed', from_stage_id: from_stage_id, to_stage_id: stage.id)
    log(deal, 'won') if stage.won?
    log(deal, 'lost', reason: deal.lost_reason) if stage.lost?
  end
end
