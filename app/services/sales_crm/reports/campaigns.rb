# Custom (MyDesk): التقرير 21, عائد الحملات (للمدير فقط) (CONVERSATION_SALES_PLAN.md): what each campaign brought.
# The deals created in the period that are credited to a campaign (SalesCrm::CampaignAttribution), split by how:
# direct (the deal's conversation came from a live chat campaign) and influenced (the customer got an SMS campaign
# shortly before); the two are never added into one number. For an SMS campaign, its recipients, the share that became
# deals, what the messages cost (delivery_price; «unknown» when any price is missing) and the revenue per riyal spent.
class SalesCrm::Reports::Campaigns < SalesCrm::Reports::Report
  KEY = 'campaigns'.freeze
  ATTRIBUTIONS = %w[direct influenced].freeze
  ZERO = { count: 0, won_count: 0, won_cents: 0 }.freeze

  def self.admin_only? = true

  def build
    rows = campaign_rows
    { rows: rows, empty: rows.empty?,
      totals: ATTRIBUTIONS.to_h { |kind| [kind.to_sym, sum(rows.map { |row| row[kind.to_sym] })] } }
  end

  # cell: campaign_id and attribution (direct or influenced; both when absent)
  def drill_scope(cell)
    relation = credited.where(campaign_id: cell[:campaign_id].to_i)
    ATTRIBUTIONS.include?(cell[:attribution].to_s) ? relation.where(campaign_attribution: cell[:attribution].to_s) : relation
  end

  private

  def credited = deals.where(created_at: period.range).where.not(campaign_id: nil)

  def campaign_rows
    counts = credited.group(:campaign_id, :campaign_attribution).count
    won_by = won_by_campaign
    campaigns = account.campaigns.where(id: counts.keys.map(&:first).uniq)
    campaigns.map { |campaign| campaign_row(campaign, counts, won_by) }.sort_by { |row| -won_total(row) }
  end

  # [campaign_id, attribution] => { won_count, won_cents }
  def won_by_campaign
    credited.won.group(:campaign_id, :campaign_attribution)
            .pluck(:campaign_id, :campaign_attribution, Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(crm_deals.amount_cents), 0)'))
            .to_h { |id, kind, count, cents| [[id, kind], { won_count: count.to_i, won_cents: cents.to_i }] }
  end

  def campaign_row(campaign, counts, won_by)
    by_kind = ATTRIBUTIONS.to_h do |kind|
      [kind.to_sym, ZERO.merge(count: counts.fetch([campaign.id, kind], 0)).merge(won_by.fetch([campaign.id, kind], {}))
                        .merge(cell: { campaign_id: campaign.id, attribution: kind })]
    end
    { campaign_id: campaign.id, title: campaign.title, sms: campaign.one_off?, **by_kind, **sms_figures(campaign, by_kind) }
  end

  # Recipients, the share that became deals, the cost and the revenue per riyal of an SMS campaign
  def sms_figures(campaign, by_kind)
    sent = SmsCampaignRecipient.where(account_id: account.id, campaign_id: campaign.id, status: :sent)
    recipients = sent.count
    cost = sent.sum(:delivery_price).to_f.round(4)
    won_cents = by_kind.values.sum { |figures| figures[:won_cents] }
    { recipients: recipients, cost: cost, cost_known: recipients.positive? && !sent.exists?(delivery_price: nil),
      conversion: SalesCrm::Metrics::Ratio.percent(by_kind.values.sum { |figures| figures[:count] }, recipients),
      return_per_riyal: cost.positive? ? (won_cents / 100.0 / cost).round(1) : nil }
  end

  def won_total(row) = ATTRIBUTIONS.sum { |kind| row[kind.to_sym][:won_cents] }

  def sum(figures)
    { count: figures.sum { |f| f[:count] }, won_count: figures.sum { |f| f[:won_count] }, won_cents: figures.sum { |f| f[:won_cents] } }
  end
end
