# Custom (MyDesk): التقرير 5, الصفقات المكسوبة والخاسرة: what closed in the period and how, against the period before
# (SalesCrm::Metrics::WinRate). Grouped by day, week (from Saturday) or month depending on the period's length, by
# employee in the team view, and the lost deals by reason (spelling variants merged, as in Reports::LostReasons).
class SalesCrm::Reports::WonLost < SalesCrm::Reports::Report
  KEY = 'won_lost'.freeze
  STATUSES = %w[won lost].freeze
  EMPTY_BUCKET = { won_count: 0, won_cents: 0, lost_count: 0, lost_cents: 0 }.freeze

  def self.list_filters = %i[product_id lead_source_id]

  def build
    totals = SalesCrm::Metrics::WinRate.call(deals, period)
    { totals: totals, previous_totals: SalesCrm::Metrics::WinRate.call(deals, period.previous),
      empty: (totals[:won_count] + totals[:lost_count]).zero?, interval: interval, buckets: buckets,
      assignees: assignee_results, lost_reasons: lost_reasons }
  end

  # cell: status (won, lost, or closed for both), and any of assignee_id, from / to (a bucket, inside the period) and
  # reason (lost)
  def drill_scope(cell)
    window = window_for(cell)
    status = cell[:status].to_s
    relation = STATUSES.include?(status) ? closed(status, window) : closed('won', window).or(closed('lost', window))
    relation = by_assignee(relation, cell)
    cell[:reason].present? ? relation.where(id: reason_ids(relation, cell[:reason].to_s)) : relation
  end

  private

  def drill_order = { amount_cents: :desc, id: :desc }

  def closed(status, window)
    status == 'won' ? deals.won.where(won_at: window.range) : deals.lost.where(lost_at: window.range)
  end

  # Every bucket of the period, empty ones included, so the chart has no gaps
  def buckets
    sums = bucket_sums
    bucket_cells.map do |start, cell|
      sums.fetch(start, EMPTY_BUCKET).merge(bucket: start.iso8601, cell: cell)
    end
  end

  # bucket start => { won_count, won_cents, lost_count, lost_cents }
  def bucket_sums
    sums = Hash.new { |h, k| h[k] = EMPTY_BUCKET.dup }
    STATUSES.each do |status|
      closed(status, period).pluck(:"#{status}_at", :amount_cents).each do |at, cents|
        bucket = sums[bucket_start(local_date(at))]
        bucket[:"#{status}_count"] += 1
        bucket[:"#{status}_cents"] += cents
      end
    end
    sums
  end

  def assignee_results
    return nil unless team_view?

    ids = STATUSES.flat_map { |status| closed(status, period).distinct.pluck(:assignee_id) }.uniq
    people = names(ids)
    rows = ids.map do |id|
      SalesCrm::Metrics::WinRate.call(deals.where(assignee_id: id), period).merge(assignee_id: id, name: people[id], cell: assignee_cell(id))
    end
    rows.sort_by { |row| -row[:won_cents] }
  end

  def lost_reasons
    groups = {}
    closed('lost', period).order(:lost_at, :id).pluck(:lost_reason, :amount_cents).each do |reason, cents|
      key = reason_key(reason)
      group = groups[key] ||= { reason: reason.presence || '-', count: 0, total_cents: 0, cell: { status: 'lost', reason: key } }
      group[:count] += 1
      group[:total_cents] += cents
    end
    groups.values.sort_by { |g| [-g[:count], -g[:total_cents]] }
  end

  def reason_key(reason) = SalesCrm::Normalize.loose(reason).presence || '-'

  def reason_ids(relation, key)
    relation.pluck(:id, :lost_reason).select { |_, reason| reason_key(reason) == key }.map(&:first)
  end
end
