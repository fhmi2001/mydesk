# Custom (MyDesk): the headline numbers of the performance report. Response and resolution times use the
# median and 90th percentile (computed in Postgres) rather than the average, which one slow conversation
# can distort; every figure comes with the same-length previous period for comparison, and conversations
# are broken down by channel (WhatsApp, Instagram, SMS, website chat, ...).
class V2::Reports::PerformanceBuilder
  include DateRangeHelper

  pattr_initialize [:account!, :params!]

  def build
    {
      current: period_stats(range),
      previous: period_stats(previous_range),
      channels: channel_stats,
      unanswered_now: account.conversations.open.where(first_reply_created_at: nil).count
    }
  end

  private

  def previous_range
    length = range.end - range.begin
    (range.begin - length)...range.begin
  end

  def period_stats(period)
    {
      conversations: account.conversations.where(created_at: period).count,
      resolved: events('conversation_resolved', period).count,
      first_response: duration_stats(events('first_response', period)),
      resolution: duration_stats(events('conversation_resolved', period))
    }
  end

  def events(name, period)
    account.reporting_events.where(name: name, created_at: period)
  end

  def value_column
    ActiveModel::Type::Boolean.new.cast(params[:business_hours]) ? 'value_in_business_hours' : 'value'
  end

  def percentile_sql(fraction)
    Arel.sql("percentile_cont(#{fraction}) WITHIN GROUP (ORDER BY reporting_events.#{value_column})")
  end

  def duration_stats(scope)
    median, p90, count = scope.pick(percentile_sql(0.5), percentile_sql(0.9), Arel.sql('COUNT(*)'))
    { median: median&.round, p90: p90&.round, count: count.to_i }
  end

  def channel_stats
    medians = channel_first_response_medians
    rows = channel_status_counts.each_with_object({}) do |((channel, status), count), stats|
      stats[channel] ||= { channel_type: channel, conversations: 0, resolved: 0, first_response_median: medians[channel]&.round }
      stats[channel][:conversations] += count
      stats[channel][:resolved] += count if status == 'resolved'
    end
    rows.values.sort_by { |row| -row[:conversations] }
  end

  def channel_status_counts
    account.conversations.joins(:inbox).where(created_at: range)
           .group('inboxes.channel_type', 'conversations.status').count
  end

  def channel_first_response_medians
    events('first_response', range).joins(:inbox).group('inboxes.channel_type')
                                   .pluck('inboxes.channel_type', percentile_sql(0.5)).to_h
  end
end
