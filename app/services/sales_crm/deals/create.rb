# Custom (MyDesk): creates a deal at the end of its stage, snapshots the contact, logs and broadcasts. An open deal
# needs an amount, an expected close date and an owner (the creator unless one is given).
class SalesCrm::Deals::Create < SalesCrm::BaseService
  PERMITTED = (%i[title amount pipeline_id stage_id contact_id assignee_id close_date description conversation_id source priority
                  forecast_category probability_override] + LIST_PARAMS).freeze

  def perform(params)
    params = params.to_h.symbolize_keys.slice(*PERMITTED)
    pipeline = account.crm_pipelines.find(params[:pipeline_id])
    stage = stage_for(pipeline, params[:stage_id])
    fail!(:lost_reason_required) if stage.lost?

    ActiveRecord::Base.transaction do
      deal = account.crm_deals.new(attributes(params, pipeline, stage))
      assign_list_items(deal, params)
      require_open_essentials!(deal)
      deal.save!
      announce(deal)
      deal
    end
  end

  private

  def announce(deal)
    log(deal, 'created', stage_id: deal.stage_id)
    broadcast('crm.deal_created', { id: deal.id, stage_id: deal.stage_id, pipeline_id: deal.pipeline_id }, to: deal.assignee_id)
  end

  def stage_for(pipeline, stage_id)
    stage = stage_id.present? ? find_stage!(pipeline, stage_id) : pipeline.first_open_stage
    fail!(:stage_required) unless stage
    stage
  end

  def attributes(params, pipeline, stage)
    {
      pipeline: pipeline, stage: stage, currency: account.crm_currency, creator: user,
      title: params[:title].to_s.strip, amount_cents: cents_from(params[:amount]) || 0,
      contact: contact_for(params[:contact_id]), assignee: assignee_for(params[:assignee_id]),
      close_date: params[:close_date].presence, description: params[:description], position: next_position(stage)
    }.merge(status_attributes(stage), origin_attributes(params), forecast_attributes(params))
  end

  def origin_attributes(params)
    conversation = conversation_for(params[:conversation_id])
    { conversation: conversation, source: source_for(params[:source], conversation) }
  end

  def forecast_attributes(params)
    { priority: params[:priority].present? ? priority_from(params[:priority]) : :medium,
      forecast_category: forecast_category_from(params[:forecast_category]),
      probability_override: probability_from(params[:probability_override]) }
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
  # The owner: the one given, else whoever creates the deal
  def assignee_for(id) = id.present? ? account.users.find(id) : user

  def conversation_for(id)
    return nil if id.blank?

    account.conversations.find_by(display_id: id) || account.conversations.find(id)
  end

  def next_position(stage)
    (account.crm_deals.kept.where(stage_id: stage.id).maximum(:position) || 0) + 1
  end
end
