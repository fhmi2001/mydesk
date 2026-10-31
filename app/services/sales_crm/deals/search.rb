# Custom (MyDesk): the deals list behind the board and the table. `scope` is an already-authorized relation
# (DealPolicy::Scope) so the own-deals-only rule is applied once, by the caller.
class SalesCrm::Deals::Search < SalesCrm::BaseService
  BOARD_PER_STAGE = 100
  TABLE_PER_PAGE = 50
  STATUSES = %w[open won lost].freeze
  SORTABLE = %w[title amount_cents close_date updated_at created_at status].freeze
  FILTERS = %i[stage_id assignee_id status q view page sort].freeze

  # filters: stage_id, assignee_id ('none' for unassigned), status, q (search text), view (:board | :table),
  # page, sort ('column:asc|desc'). Returns { deals:, counts: { stage_id => { count:, total_cents: } }, total:, page: }
  def perform(scope, pipeline:, **filters)
    filters = filters.slice(*FILTERS)
    relation = filtered(scope.where(pipeline_id: pipeline.id), filters)
    counts = counts_for(relation)
    deals = filters[:view].to_s == 'table' ? table(relation, filters[:page], filters[:sort]) : board(relation, pipeline)
    { deals: deals, counts: counts, total: counts.values.sum { |c| c[:count] }, page: filters[:page].to_i }
  end

  private

  def filtered(relation, filters)
    relation = relation.where(stage_id: filters[:stage_id]) if filters[:stage_id].present?
    relation = relation.where(assignee_id: filters[:assignee_id] == 'none' ? nil : filters[:assignee_id]) if filters[:assignee_id].present?
    relation = relation.where(status: filters[:status]) if STATUSES.include?(filters[:status].to_s)
    search(relation, filters[:q])
  end

  def counts_for(relation)
    relation.group(:stage_id).pluck(:stage_id, Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(amount_cents), 0)'))
            .to_h { |id, count, total| [id, { count: count, total_cents: total.to_i }] }
  end

  def search(relation, query)
    term = SalesCrm::Normalize.text(query)
    return relation if term.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
    relation.where('crm_deals.title_normalized LIKE :p OR crm_deals.contact_name_normalized LIKE :p', p: pattern)
  end

  # The first BOARD_PER_STAGE deals of every stage, in position order, in one query
  def board(relation, pipeline)
    ranked = relation.select('crm_deals.*, ROW_NUMBER() OVER (PARTITION BY stage_id ORDER BY position ASC, id DESC) AS stage_rank')
    SalesCrm::Deal.from(ranked, :crm_deals).where(stage_rank: ..BOARD_PER_STAGE)
                  .where(pipeline_id: pipeline.id).order(:stage_id, :position, id: :desc)
                  .includes(:contact, :assignee, :conversation)
  end

  def table(relation, page, sort)
    column, direction = (sort.presence || 'updated_at:desc').split(':')
    column = 'updated_at' unless SORTABLE.include?(column)
    relation.order(column => direction == 'asc' ? :asc : :desc, :id => :desc).includes(:contact, :assignee, :stage, :conversation)
            .page(page.to_i.clamp(1, 10_000)).per(TABLE_PER_PAGE)
  end
end
