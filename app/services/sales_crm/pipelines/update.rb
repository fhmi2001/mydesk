# Custom (MyDesk): renames a pipeline and rewrites its stages in one transaction. Stages carry their id to
# be kept; a stage left out is removed, and if it still has deals the caller must name a target stage in
# `stage_moves` ({ removed_stage_id => target_stage_id }) or the whole update is refused.
class SalesCrm::Pipelines::Update < SalesCrm::BaseService
  STATUS_BY_KIND = { 'open' => 0, 'won' => 1, 'lost' => 2 }.freeze

  def perform(pipeline, name: nil, currency: nil, stages: nil, stage_moves: {})
    ActiveRecord::Base.transaction do
      pipeline.name = name.to_s.strip if name.present?
      pipeline.currency = currency.to_s.upcase if currency.present?
      pipeline.save!
      rewrite_stages(pipeline, stages, stage_moves.to_h) unless stages.nil?
      pipeline.stages.reload
      pipeline
    end
  rescue ActiveRecord::RecordInvalid => e
    raise SalesCrm::ValidationError, e.record.errors.full_messages.to_sentence
  end

  private

  def rewrite_stages(pipeline, rows, stage_moves)
    rows = rows.map { |r| r.to_h.symbolize_keys }
    remove_missing(pipeline, rows, stage_moves)
    # Park every position out of the way so reordering never trips the unique index mid-way
    pipeline.stages.reload.each { |s| s.update_columns(position: s.position + 1000) } # rubocop:disable Rails/SkipsModelValidations
    rows.each_with_index { |row, index| write_stage(pipeline, row, index) }
    sync_deal_statuses(pipeline)
  end

  def remove_missing(pipeline, rows, stage_moves)
    kept_ids = rows.filter_map { |r| r[:id].presence&.to_i }
    removed = pipeline.stages.reject { |s| kept_ids.include?(s.id) }
    removed.each { |stage| empty_stage(pipeline, stage, stage_moves[stage.id.to_s] || stage_moves[stage.id]) }
    removed.each(&:destroy!)
  end

  def write_stage(pipeline, row, index)
    stage = row[:id].present? ? pipeline.stages.find { |s| s.id == row[:id].to_i } : pipeline.stages.build(account: account)
    fail!(:invalid_stage) unless stage

    color = row[:color].presence || stage.color.presence || SalesCrm::Stage::DEFAULT_COLORS[row[:kind].to_s]
    stage.assign_attributes(name: row[:name], probability: row[:probability], kind: row[:kind], position: index, color: color)
    stage.save!
  end

  def empty_stage(pipeline, stage, target_id)
    deals = account.crm_deals.where(stage_id: stage.id)
    return unless deals.exists?

    target = pipeline.stages.find { |s| s.id == target_id.to_i && s.id != stage.id }
    fail!(:stage_has_deals) unless target

    mover = SalesCrm::Deals::Move.new(account: account, user: user)
    deals.find_each { |deal| mover.perform(deal, stage_id: target.id, lost_reason: deal.lost_reason.presence || '-') }
  end

  # A stage's kind may have changed: keep every deal's status in step with its stage
  def sync_deal_statuses(pipeline)
    pipeline.stages.each do |stage|
      status = STATUS_BY_KIND[stage.kind]
      account.crm_deals.where(stage_id: stage.id).where.not(status: status).update_all(status: status) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
