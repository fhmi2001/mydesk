# Custom (MyDesk): التقرير 13, حركة خط الأنابيب (للمدير): what moved forward, back or out in the period (the last 7 days
# unless a range is given). Every deal is compared as it stood at the start and at the end of the period, rebuilt from
# the activity log: its stage (SalesCrm::Metrics::StageStays; forward or back by stage order), its value (undoing the
# amount changes after a moment) and its expected close date (Metrics::Slippage.date_at). The waterfall runs from the
# open value at the start to the open value at the end:
#   start + new + increased − decreased − won − lost = end
# A deal created in the period starts from its first value; a deal closed in it changes up to its closing value.
class SalesCrm::Reports::Changes < SalesCrm::Reports::Report
  KEY = 'changes'.freeze
  MOVES = %w[new advanced moved_back slipped won lost increased decreased].freeze

  def self.admin_only? = true
  def self.list_filters = %i[product_id lead_source_id]

  def initialize(account:, user:, **filters)
    super
    @period = SalesCrm::Period.new(today - 6, today, zone) if filters[:from].blank?
  end

  def build
    rows = deal_changes
    { totals: summary(rows), empty: rows.empty?, assignees: per_assignee(rows) }
  end

  # cell: move (one of MOVES) and assignee_id
  def drill_scope(cell)
    move = cell[:move].to_s
    ids = deal_changes.select { |row| MOVES.include?(move) ? row[:moves].include?(move) : row[:moves].any? }.pluck(:id)
    by_assignee(deals.where(id: ids), cell)
  end

  private

  def drill_order = { amount_cents: :desc, id: :desc }

  def starts = period.begins_at
  def ends = period.ends_at

  # The deals that were open at some point in the period
  def candidates
    closed_before = deals.where(won_at: ...starts).or(deals.where(lost_at: ...starts))
    deals.where(created_at: ..ends).where.not(id: closed_before.select(:id))
  end

  # [{ id, assignee_id, moves: [..], start_cents, new_cents, delta_cents, closed_cents }]
  def deal_changes
    @deal_changes ||= begin
      relation = candidates
      positions = account.crm_stages.where(kind: :open).pluck(:id, :position).to_h
      stays = SalesCrm::Metrics::StageStays.call(account, relation)
      logs = changes_since(relation.pluck(:id))
      relation.pluck(:id, :assignee_id, :created_at, :won_at, :lost_at, :amount_cents, :close_date).filter_map do |id, owner, *deal|
        row = change_for(deal, stays[id][:stays], logs.fetch(id, {}), positions)
        row.merge(id: id, assignee_id: owner) if row[:moves].any?
      end
    end
  end

  # deal id => { 'amount_changed' => [[at, from]], 'close_date_changed' => [[at, from]] }, newest first
  def changes_since(ids)
    account.crm_activities.where(deal_id: ids, kind: %w[amount_changed close_date_changed], created_at: starts..)
           .order(created_at: :desc, id: :desc).pluck(:deal_id, :kind, :created_at, :data)
           .group_by(&:first).transform_values do |rows|
      rows.group_by(&:second).transform_values { |list| list.map { |_, _, at, data| [at, data['from']] } }
    end
  end

  def amount_at(current, changes, moment)
    Array(changes).reduce(current) { |amount, (at, from)| at > moment ? from.to_i : amount }
  end

  # deal: [created_at, won_at, lost_at, amount_cents, close_date]
  def change_for(deal, stays, logs, positions)
    created_at, won_at, lost_at, amount, close_date = deal
    closing, closed_at = closing_in_period(won_at, lost_at)
    from = [created_at, starts].max
    first = amount_at(amount, logs['amount_changed'], from)
    delta = amount_at(amount, logs['amount_changed'], closed_at || ends) - first
    is_new = created_at >= starts
    moves = [('new' if is_new), value_move(delta), closing]
    moves += open_moves(stays, close_date, logs, from, positions) unless closing
    values(first, delta, is_new, closing).merge(moves: moves.compact)
  end

  # ['won' or 'lost', when] for a deal closed in the period
  def closing_in_period(won_at, lost_at)
    return ['won', won_at] if won_at && period.range.cover?(won_at)

    ['lost', lost_at] if lost_at && period.range.cover?(lost_at)
  end

  def values(first, delta, is_new, closing)
    { start_cents: is_new ? 0 : first, new_cents: is_new ? first : 0, delta_cents: delta, closed_cents: closing ? first + delta : 0 }
  end

  def value_move(delta)
    return nil if delta.zero?

    delta.positive? ? 'increased' : 'decreased'
  end

  def open_moves(stays, close_date, logs, from, positions)
    [stage_move(stays, from, positions), ('slipped' if slipped?(close_date, logs['close_date_changed'], from))]
  end

  def stage_move(stays, from, positions)
    before = positions[SalesCrm::Metrics::StageStays.stage_at(stays, from)]
    after = positions[SalesCrm::Metrics::StageStays.stage_at(stays, ends)]
    return nil unless before && after && before != after

    after > before ? 'advanced' : 'moved_back'
  end

  def slipped?(close_date, changes, from)
    before = SalesCrm::Metrics::Slippage.date_at(close_date, changes, from)
    after = SalesCrm::Metrics::Slippage.date_at(close_date, changes, ends)
    before.present? && after.present? && after > before
  end

  def summary(rows)
    { counts: MOVES.index_with { |move| with_move(rows, move).size }, waterfall: waterfall(rows) }
  end

  def with_move(rows, move) = rows.select { |r| r[:moves].include?(move) }

  def waterfall(rows)
    deltas = rows.pluck(:delta_cents)
    steps = { start: open_value_at(starts), new: rows.sum { |r| r[:new_cents] }, increased: deltas.select(&:positive?).sum,
              decreased: -deltas.select(&:negative?).sum, won: closed_value(rows, 'won'), lost: closed_value(rows, 'lost') }
    steps.merge(end: steps.values_at(:start, :new, :increased).sum - steps.values_at(:decreased, :won, :lost).sum)
  end

  def closed_value(rows, move) = with_move(rows, move).sum { |r| r[:closed_cents] }

  # The open value at the start of the period, each deal at its value then
  def open_value_at(moment)
    relation = candidates.where(created_at: ...moment)
    logs = changes_since(relation.pluck(:id))
    relation.pluck(:id, :amount_cents).sum { |id, amount| amount_at(amount, logs.dig(id, 'amount_changed'), moment) }
  end

  def per_assignee(rows)
    return nil unless team_view?

    people = names(rows.pluck(:assignee_id))
    result = rows.group_by { |r| r[:assignee_id] }.map do |id, mine|
      { assignee_id: id, name: people[id], cell: assignee_cell(id),
        counts: MOVES.index_with { |move| mine.count { |r| r[:moves].include?(move) } } }
    end
    result.sort_by { |row| -row[:counts].values.sum }
  end
end
