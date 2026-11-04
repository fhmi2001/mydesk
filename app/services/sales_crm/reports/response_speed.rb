# Custom (MyDesk): التقرير 20, سرعة الرد ونسبة الكسب (CONVERSATION_SALES_PLAN.md): do deals answered faster close
# better? The deals closed in the period, by the first reply in the conversation they came from (Chatwoot's
# first_response event, in real time, not working hours), in five buckets: how many closed, the win rate and the
# average won. A bucket under 10 deals gives no rate (a small sample). Deals without a conversation, or whose
# conversation has no reply yet, are left out and counted. It shows a correlation, not a cause.
class SalesCrm::Reports::ResponseSpeed < SalesCrm::Reports::Report
  KEY = 'response_speed'.freeze
  MIN_SAMPLE = 10
  # key, from (seconds, included), to (excluded)
  BUCKETS = [['under_5m', 0, 300], ['5_30m', 300, 1800], ['30m_2h', 1800, 7200], ['2h_24h', 7200, 86_400],
             ['over_24h', 86_400, nil]].freeze

  def self.list_filters = %i[product_id lead_source_id]

  def build
    timed = timed_deals
    buckets = BUCKETS.map { |key, *| bucket_row(key, timed.select { |row| row[:bucket] == key }) }
    { buckets: buckets, min_sample: MIN_SAMPLE, empty: timed.empty?,
      totals: { closed_count: timed.size, excluded_count: closed_deals.count - timed.size } }
  end

  # cell: bucket (one of BUCKETS' keys)
  def drill_scope(cell)
    deals.where(id: timed_deals.select { |row| row[:bucket] == cell[:bucket].to_s }.pluck(:id))
  end

  private

  def drill_order = { won_at: :desc, lost_at: :desc, id: :desc }

  def closed_deals
    deals.won.where(won_at: period.range).or(deals.lost.where(lost_at: period.range))
  end

  # [{ id, status, amount_cents, bucket }] for the closed deals whose conversation has a first reply
  def timed_deals
    @timed_deals ||= begin
      closed = closed_deals.where.not(conversation_id: nil)
      seconds = first_replies(closed.select(:conversation_id))
      closed.pluck(:id, :conversation_id, :status, :amount_cents).filter_map do |id, conversation_id, status, cents|
        value = seconds[conversation_id]
        { id: id, status: status, amount_cents: cents, bucket: bucket_for(value) } if value
      end
    end
  end

  # conversation_id => seconds to the first reply (the earliest first_response event of the conversation)
  def first_replies(conversation_ids)
    ReportingEvent.where(account_id: account.id, name: 'first_response', conversation_id: conversation_ids)
                  .order(:created_at).pluck(:conversation_id, :value)
                  .each_with_object({}) { |(conversation_id, value), map| map[conversation_id] ||= value.to_f }
  end

  def bucket_for(seconds)
    BUCKETS.find { |_, low, high| seconds >= low && (high.nil? || seconds < high) }.first
  end

  def bucket_row(key, rows)
    won = rows.select { |row| row[:status] == 'won' }
    won_cents = won.sum { |row| row[:amount_cents] }
    small = rows.size < MIN_SAMPLE
    { key: key, closed_count: rows.size, won_count: won.size, won_cents: won_cents, small_sample: small,
      win_rate: small ? nil : SalesCrm::Metrics::Ratio.percent(won.size, rows.size),
      average_won_cents: SalesCrm::Metrics::Ratio.average_cents(won_cents, won.size), cell: { bucket: key } }
  end
end
