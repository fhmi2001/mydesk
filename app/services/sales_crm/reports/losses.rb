# Custom (MyDesk): التقرير 12, تحليل أسباب الخسارة: why we lose, and to whom. The deals lost in the period by reason
# (spelling variants merged, as in Reports::WonLost), by competitor, by the stage they were in when lost (the last
# move into a lost stage in the activity log; «unknown» for deals lost without one) and, in the team view, by employee.
class SalesCrm::Reports::Losses < SalesCrm::Reports::Report
  KEY = 'losses'.freeze
  UNKNOWN = 'unknown'.freeze

  def self.list_filters = %i[product_id lead_source_id]

  def build
    previous = deals.lost.where(lost_at: period.previous.range)
    { totals: totals(rows), previous_totals: { count: previous.count, total_cents: previous.sum(:amount_cents) },
      empty: rows.empty?, reasons: reasons, competitors: competitors, stages: stages, assignees: assignees }
  end

  # cell: any of reason, competitor_id, from_stage_id ('unknown' too) and assignee_id
  def drill_scope(cell)
    keep = rows.select do |row|
      (cell[:reason].blank? || reason_key(row[:reason]) == cell[:reason].to_s) &&
        (cell[:from_stage_id].blank? || stage_key(row[:from_stage_id]) == cell[:from_stage_id].to_s)
    end
    by_lists(by_assignee(lost, cell), cell).where(id: keep.pluck(:id))
  end

  private

  def lost = deals.lost.where(lost_at: period.range)

  # Every deal lost in the period, with what the groups read
  def rows
    @rows ||= begin
      data = lost.order(:lost_at, :id).pluck(:id, :lost_reason, :competitor_id, :assignee_id, :amount_cents)
      from = from_stages(data.map(&:first))
      data.map do |id, reason, competitor, assignee, cents|
        { id: id, reason: reason, competitor_id: competitor, assignee_id: assignee, cents: cents, from_stage_id: from[id] }
      end
    end
  end

  # deal id => the stage it left for a lost stage (its last such move)
  def from_stages(ids)
    lost_stages = account.crm_stages.where(kind: :lost).pluck(:id).map(&:to_s)
    moves = account.crm_activities.where(deal_id: ids, kind: 'stage_changed').order(:created_at, :id).pluck(:deal_id, :data)
    moves.each_with_object({}) do |(deal_id, data), from|
      from[deal_id] = data['from_stage_id'] if lost_stages.include?(data['to_stage_id'].to_s)
    end
  end

  def reason_key(reason) = SalesCrm::Normalize.loose(reason).presence || '-'
  def stage_key(id) = id.presence&.to_s || UNKNOWN

  def totals(group_rows) = { count: group_rows.size, total_cents: group_rows.sum { |r| r[:cents] } }

  # [{ key, name, count, total_cents, cell }], most lost first
  def group_by_key(cell_key, names, &)
    groups = rows.group_by(&).map do |key, mine|
      totals(mine).merge(key: key, name: names.call(key, mine), cell: { cell_key => key.nil? ? NONE : key })
    end
    groups.sort_by { |g| [-g[:count], -g[:total_cents]] }
  end

  def reasons
    group_by_key(:reason, ->(_, mine) { mine.first[:reason].presence || '-' }) { |row| reason_key(row[:reason]) }
  end

  def competitors
    labels = item_names(rows.pluck(:competitor_id))
    group_by_key(:competitor_id, ->(key, _) { labels[key] }) { |row| row[:competitor_id] }
  end

  def stages
    labels = account.crm_stages.where(id: rows.filter_map { |r| r[:from_stage_id] }).pluck(:id, :name).to_h.transform_keys(&:to_s)
    group_by_key(:from_stage_id, ->(key, _) { labels[key] }) { |row| stage_key(row[:from_stage_id]) }
  end

  def assignees
    return nil unless team_view?

    people = names(rows.pluck(:assignee_id))
    group_by_key(:assignee_id, ->(key, _) { people[key] }) { |row| row[:assignee_id] }.each do |g|
      g.merge!(assignee_id: g[:key], top_reason: top_reason(rows.select { |r| r[:assignee_id] == g[:key] }))
    end
  end

  def top_reason(mine) = mine.group_by { |r| reason_key(r[:reason]) }.max_by { |_, v| v.size }&.last&.first&.dig(:reason)
end
