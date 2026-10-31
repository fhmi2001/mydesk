# Custom (MyDesk): creates a deal at the end of its stage, snapshots the contact, logs and broadcasts
class SalesCrm::Deals::Create < SalesCrm::BaseService
  PERMITTED = %i[title amount pipeline_id stage_id contact_id assignee_id close_date description conversation_id source].freeze

  def perform(params)
    params = params.to_h.symbolize_keys.slice(*PERMITTED)
    pipeline = account.crm_pipelines.find(params[:pipeline_id])
    stage = stage_for(pipeline, params[:stage_id])
    fail!(:lost_reason_required) if stage.lost?

    ActiveRecord::Base.transaction do
      deal = account.crm_deals.create!(attributes(params, pipeline, stage))
      log(deal, 'created', stage_id: stage.id)
      broadcast('crm.deal_created', id: deal.id, stage_id: stage.id, pipeline_id: pipeline.id)
      deal
    end
  end

  private

  def stage_for(pipeline, stage_id)
    stage = stage_id.present? ? find_stage!(pipeline, stage_id) : pipeline.first_open_stage
    fail!(:stage_required) unless stage
    stage
  end

  def attributes(params, pipeline, stage)
    conversation = conversation_for(params[:conversation_id])
    {
      pipeline: pipeline, stage: stage, currency: pipeline.currency, creator: user,
      title: params[:title].to_s.strip, amount_cents: cents_from(params[:amount]) || 0,
      contact: contact_for(params[:contact_id]), assignee: assignee_for(params[:assignee_id]),
      close_date: params[:close_date].presence, description: params[:description],
      conversation: conversation, source: source_for(params[:source], conversation),
      position: next_position(stage)
    }.merge(status_attributes(stage))
  end

  def status_attributes(stage)
    { status: { 'open' => :open, 'won' => :won, 'lost' => :lost }[stage.kind],
      won_at: (Time.current if stage.won?), lost_at: (Time.current if stage.lost?) }
  end

  def source_for(source, conversation)
    return source if source.present?

    conversation ? :conversation_source : :manual
  end

  def contact_for(id) = id.present? ? account.contacts.find(id) : nil
  def assignee_for(id) = id.present? ? account.users.find(id) : nil

  def conversation_for(id)
    return nil if id.blank?

    account.conversations.find_by(display_id: id) || account.conversations.find(id)
  end

  def next_position(stage)
    (account.crm_deals.kept.where(stage_id: stage.id).maximum(:position) || 0) + 1
  end
end
