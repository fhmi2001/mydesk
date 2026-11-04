# Custom (MyDesk): المؤشر 8, نسبة التأجيل: of the deals expected to close in the period (their expected close date fell
# in it when the period began), how many had that date pushed past the period's end and were not closed in it.
# The dates are rebuilt from the close_date_changed log, so changes made before that log existed are unknown and
# such deals count with the date they have now (gap-analysis.md).
module SalesCrm::Metrics::Slippage
  module_function

  def call(account, deals, period)
    candidates = deals.where(created_at: ...period.begins_at).pluck(:id, :close_date, :won_at, :lost_at).to_h { |id, *rest| [id, rest] }
    changes = changes_since(account, candidates.keys, period.begins_at)
    expected = candidates.select { |id, (close_date, *)| period.dates.cover?(date_at(close_date, changes[id], period.begins_at)) }
    slipped = expected.count { |id, (close_date, won_at, lost_at)| slipped?(close_date, changes[id], won_at || lost_at, period) }
    { expected_count: expected.size, slipped_count: slipped, rate: SalesCrm::Metrics::Ratio.percent(slipped, expected.size) }
  end

  # Still not closed by the end of the period, and by then expected after it
  def slipped?(close_date, changes, closed_at, period)
    return false if closed_at.present? && period.range.cover?(closed_at)

    date_at_end = date_at(close_date, changes, period.ends_at)
    date_at_end.present? && date_at_end > period.last
  end

  # deal_id => [[changed_at, from_date], ...] newest first, for the changes made since `since`
  def changes_since(account, deal_ids, since)
    account.crm_activities.where(deal_id: deal_ids, kind: 'close_date_changed', created_at: since..)
           .order(created_at: :desc).pluck(:deal_id, :created_at, :data)
           .group_by(&:first).transform_values { |rows| rows.map { |_, at, data| [at, data['from']] } }
  end

  # The expected close date the deal had at `moment`: undo, newest first, every change made after it
  def date_at(current, changes, moment)
    date = current
    Array(changes).each { |at, from| date = from.present? ? Date.iso8601(from) : nil if at > moment }
    date
  end
end
