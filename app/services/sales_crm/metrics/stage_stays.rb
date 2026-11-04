# Custom (MyDesk): each deal's stays in its stages, rebuilt from the activity log (created, stage_changed, reopened), for
# the time-in-stage report (11) and the pipeline changes (13). A stay starts when the deal enters a stage and ends when
# it leaves; the current stay has no end yet. A deal created before the log existed has no creation entry: its first
# known stage is the one its first logged move left (else its current stage), from its creation date, so its early
# stays are approximate.
module SalesCrm::Metrics::StageStays
  Stay = Struct.new(:stage_id, :from, :to, keyword_init: true) do
    def days(now = Time.current) = ((to || now) - from) / 1.day
  end

  module_function

  # deal id => { stays: [Stay], logged: whether the log has the deal's creation }
  def call(account, deals)
    rows = deals.pluck(:id, :stage_id, :created_at)
    events = account.crm_activities.where(deal_id: rows.map(&:first), kind: %w[created stage_changed reopened])
                    .order(:created_at, :id).pluck(:deal_id, :kind, :data, :created_at).group_by(&:first)
    rows.to_h do |id, current, created_at|
      deal_events = events.fetch(id, [])
      [id, { stays: stays(deal_events, current, created_at), logged: deal_events.any? { |e| e[1] == 'created' } }]
    end
  end

  def stays(events, current, created_at)
    moves = events.reject { |e| e[1] == 'created' }
    moves.each_with_object([Stay.new(stage_id: first_stage(events, moves, current).to_i, from: created_at)]) do |(_, _, data, at), list|
      list.last.to = at
      list << Stay.new(stage_id: data['to_stage_id'].to_i, from: at)
    end
  end

  # The stage it was created in, else the one its first logged move left, else where it is now
  def first_stage(events, moves, current)
    events.find { |e| e[1] == 'created' }&.dig(2, 'stage_id') || moves.first&.dig(2, 'from_stage_id') || current
  end

  # The stage a deal was in at `moment` (nil before it was created)
  def stage_at(stays, moment)
    stays.reverse.find { |stay| stay.from <= moment }&.stage_id
  end
end
