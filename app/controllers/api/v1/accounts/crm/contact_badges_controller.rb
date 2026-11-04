# Custom (MyDesk): the deal badge of each conversation card (CONVERSATION_SALES_PLAN.md), for up to 100
# contacts in one request: how many open deals the user may see for each contact, their total, and the stage of the
# biggest one. Contacts without a visible open deal are left out.
class Api::V1::Accounts::Crm::ContactBadgesController < Api::V1::Accounts::Crm::BaseController
  LIMIT = 100

  def index
    ids = Array(params[:contact_ids]).map(&:to_i).uniq
    raise SalesCrm::ValidationError, I18n.t('sales_crm.errors.too_many_contacts', count: LIMIT) if ids.size > LIMIT

    render json: { badges: badges(deals_scope.kept.open.where(contact_id: ids)) }
  end

  private

  def badges(deals)
    counts = deals.group(:contact_id).count
    totals = deals.group(:contact_id).sum(:amount_cents)
    stages = biggest_stages(deals)
    counts.to_h do |contact_id, count|
      [contact_id, { count: count, total_cents: totals[contact_id], currency: Current.account.crm_currency,
                     stage: stages[contact_id] }]
    end
  end

  # The stage of each contact's biggest open deal
  def biggest_stages(deals)
    rows = deals.reorder(amount_cents: :desc, id: :asc).pluck(:contact_id, :stage_id)
    first_stage = rows.each_with_object({}) { |(contact_id, stage_id), map| map[contact_id] ||= stage_id }
    stages = Current.account.crm_stages.where(id: first_stage.values.uniq).index_by(&:id)
    first_stage.transform_values { |stage_id| stages[stage_id] && SalesCrm::Presenter.stage_badge(stages[stage_id]) }
  end
end
