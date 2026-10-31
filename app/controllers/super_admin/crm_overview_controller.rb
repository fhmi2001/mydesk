# Custom (MyDesk): Super Admin > Monitor > CRM. Which accounts have the Sales CRM on and how much they use
# it, and a read-only view of every account's deals. Every view of merchant deals is written to the log.
class SuperAdmin::CrmOverviewController < SuperAdmin::ApplicationController
  PER_PAGE = 50
  KINDS = %w[open won lost].freeze

  def show
    @accounts = Account.order(:id).page(params[:page]).per(PER_PAGE)
    deal_counts = SalesCrm::Deal.kept.where(account_id: @accounts.map(&:id)).group(:account_id).count
    task_counts = SalesCrm::Task.open.where(account_id: @accounts.map(&:id)).group(:account_id).count
    @rows = @accounts.map do |account|
      { account: account, enabled: account.feature_enabled?('sales_crm'), deals: deal_counts[account.id] || 0,
        open_tasks: task_counts[account.id] || 0 }
    end
    @enabled_count = Account.all.count { |a| a.feature_enabled?('sales_crm') }
  end

  def deals
    audit('deals', params[:account_id])
    @filters = filters
    scope = filtered_deals
    @deals = scope.includes(:account, :pipeline, :stage, :assignee).order(updated_at: :desc).page(params[:page]).per(PER_PAGE)
    @totals = totals_for(scope)
    @accounts = Account.where(id: SalesCrm::Deal.kept.distinct.select(:account_id)).order(:name)
  end

  def deal
    @deal = SalesCrm::Deal.includes(:account, :pipeline, :stage, :assignee, :contact, notes: :user, activities: :user).find(params[:id])
    audit('deal', @deal.account_id)
  end

  private

  def filters
    { account_id: params[:account_id].presence, status: (params[:status] if KINDS.include?(params[:status].to_s)),
      from: params[:from].presence, to: params[:to].presence }
  end

  def filtered_deals
    scope = SalesCrm::Deal.kept
    scope = scope.where(account_id: @filters[:account_id]) if @filters[:account_id]
    scope = scope.where(status: @filters[:status]) if @filters[:status]
    scope = scope.where(updated_at: Date.parse(@filters[:from]).beginning_of_day..) if @filters[:from]
    scope = scope.where(updated_at: ..Date.parse(@filters[:to]).end_of_day) if @filters[:to]
    scope
  end

  def totals_for(scope)
    counts = scope.group(:account_id, :status).count
    sums = scope.group(:account_id, :status).sum(:amount_cents)
    account_ids = counts.keys.map(&:first).uniq
    names = Account.where(id: account_ids).pluck(:id, :name).to_h
    account_ids.map { |id| total_row(id, names[id], counts, sums) }
  end

  def total_row(account_id, name, counts, sums)
    { account_id: account_id, name: name,
      open: counts[[account_id, 'open']] || 0, won: counts[[account_id, 'won']] || 0, lost: counts[[account_id, 'lost']] || 0,
      won_cents: sums[[account_id, 'won']] || 0, open_cents: sums[[account_id, 'open']] || 0 }
  end

  def audit(view, account_id)
    Rails.logger.info("[CRM audit] super_admin=#{current_super_admin.id} view=#{view} account_id=#{account_id.presence || 'all'} " \
                      "id=#{params[:id].presence || '-'}")
  end
end
