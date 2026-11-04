# Custom (MyDesk): the reference numbers of CRM_REPORTS_PLAN.md phase 6, worked out apart from the app. It reads the
# demo data (SalesCrm::DemoSeed) as plain rows — deals, log entries, targets, tasks, notes — and applies the metrics
# sheet's definitions directly; it never calls SalesCrm::Metrics or SalesCrm::Reports. The result is a list of
# { report, as, params, expect: { path => value } } that spec/services/sales_crm/reports/catalog_acceptance_spec.rb runs against
# the real reports. Paths read like `totals.won_count` or `rows[name=باقة الرسائل].by_count`.
# rubocop:disable Metrics/ClassLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity -- each definition written out in one place, to be read against the metrics sheet
class SalesCrm::ExpectedNumbers
  ZONE = ActiveSupport::TimeZone['Asia/Riyadh']
  STALE_DAYS = 14
  ATTRIBUTIONS = %w[direct influenced].freeze

  def initialize(seed)
    @seed = seed
    @account = seed.account
    @anchor = seed.anchor
    @now = ZONE.local(@anchor.year, @anchor.month, @anchor.day, 18)
    load_rows
  end

  def entries
    [pipeline, closing, stale, tasks, won_lost, quota, forecast, coverage, win_rate, losses, activity, new_deals, data_quality,
     scorecard, conversion, cycle, changes, revenue, deal_size, response_speed, campaigns, conversation_deals].flatten
  end

  private

  attr_reader :deals, :stages, :events, :targets, :tasks_rows, :notes, :names

  # ---- the raw data ----------------------------------------------------------------------------------------------

  def load_rows
    @stages = @account.crm_stages.to_h { |s| [s.id, { name: s.name, probability: s.probability, kind: s.kind, position: s.position }] }
    @deals = @account.crm_deals.where(discarded_at: nil).map do |d|
      d.attributes.symbolize_keys.slice(:id, :assignee_id, :stage_id, :status, :amount_cents, :close_date, :won_at, :lost_at,
                                        :created_at, :last_activity_at, :product_id, :lead_source_id, :competitor_id,
                                        :conversation_id, :active_conversation_id, :campaign_id, :campaign_attribution)
    end
    load_conversation_rows
    @events = @account.crm_activities.order(:created_at, :id).pluck(:deal_id, :kind, :data, :created_at).group_by(&:first)
    @targets = @account.crm_targets.pluck(:user_id, :period_start, :amount_cents)
    @tasks_rows = SalesCrm::Task.where(account_id: @account.id).pluck(:assignee_id, :kind, :status, :due_at, :done_at)
    @notes = SalesCrm::Note.where(account_id: @account.id).pluck(:user_id, :created_at)
    @names = @account.crm_list_items.pluck(:id, :name).to_h.merge(@account.users.pluck(:id, :name).to_h.transform_keys { |k| "u#{k}" })
    @first = @seed.employee(0).id
  end

  # The conversation side (CONVERSATION_SALES_PLAN.md): conversations, the employees' public replies, the first replies,
  # campaigns and their SMS recipients
  def load_conversation_rows
    @conversations = Conversation.where(account_id: @account.id).pluck(:id, :inbox_id, :assignee_id, :created_at)
    @replies = Message.where(account_id: @account.id, message_type: Message.message_types['outgoing'], private: false, sender_type: 'User')
                      .pluck(:conversation_id, :sender_id, :created_at)
    @first_replies = ReportingEvent.where(account_id: @account.id, name: 'first_response').order(:created_at)
                                   .pluck(:conversation_id, :value).each_with_object({}) { |(c, v), map| map[c] ||= v }
    @campaigns = Campaign.where(account_id: @account.id).pluck(:id, :title).to_h
    @recipients = SmsCampaignRecipient.where(account_id: @account.id, status: SmsCampaignRecipient.statuses['sent'])
                                      .pluck(:campaign_id, :delivery_price)
    @inbox_names = @account.inboxes.pluck(:id, :name).to_h
  end

  def day(time) = time.in_time_zone(ZONE).to_date
  def within(time, from, to) = time && day(time).between?(from, to)
  def mine(rows, user) = user ? rows.select { |d| d[:assignee_id] == user } : rows
  def open_deals(rows = deals) = rows.select { |d| d[:status] == 'open' }
  def won_in(from, to, rows = deals) = rows.select { |d| d[:status] == 'won' && within(d[:won_at], from, to) }
  def lost_in(from, to, rows = deals) = rows.select { |d| d[:status] == 'lost' && within(d[:lost_at], from, to) }
  def probability(deal) = stages.dig(deal[:stage_id], :probability).to_i
  def percent(part, whole) = whole.to_f.zero? ? nil : (part.to_f * 100 / whole).round(1)
  def cents(rows) = rows.sum { |d| d[:amount_cents] }
  def user_name(id) = names["u#{id}"]
  def item(name) = names.key(name)

  # A target for whole months: the month's amount; the team's is everyone's
  def target(from, to, user = nil)
    months = (from..to).map(&:beginning_of_month).uniq
    targets.select { |u, start, _| months.include?(start) && (user.nil? || u == user) }.sum do |_, start, amount|
      days = ([to, start.end_of_month].min - [from, start].max).to_i + 1
      (amount * days / start.end_of_month.day.to_r).round
    end
  end

  def entry(report, as, params, expect) = { 'report' => report, 'as' => as, 'params' => params.transform_keys(&:to_s), 'expect' => expect }

  def month(date) = { from: date.beginning_of_month.iso8601, to: date.end_of_month.iso8601 }
  def october = month(Date.new(@anchor.year, @anchor.month))
  def next_month = month(@anchor.next_month)
  def quarter = { from: (@anchor.beginning_of_quarter << 3).iso8601, to: (@anchor.beginning_of_quarter - 1).iso8601 }
  def dates(params) = [Date.iso8601(params[:from]), Date.iso8601(params[:to])]

  # ---- the reports ---------------------------------------------------------------------------------------------

  def pipeline
    [nil, @first].map do |user|
      rows = open_deals(mine(deals, user))
      entry('pipeline_by_stage', user ? 'employee' : 'manager', {},
            'totals.count' => rows.size, 'totals.total_cents' => cents(rows),
            'totals.weighted_cents' => rows.sum { |d| d[:amount_cents] * probability(d) } / 100)
    end
  end

  def closing
    from, to = dates(next_month)
    [nil, @first].map do |user|
      rows = open_deals(mine(deals, user)).select { |d| d[:close_date]&.between?(from, to) }
      entry('closing', user ? 'employee' : 'manager', next_month,
            'totals.count' => rows.size, 'totals.total_cents' => cents(rows),
            'totals.weighted_cents' => rows.sum { |d| d[:amount_cents] * probability(d) } / 100)
    end
  end

  # المؤشر 9 (decision ح): from the later of the last activity and the owner's last public reply in the deal's active
  # conversation, else from its creation
  def quiet?(deal)
    replied = @replies.select { |c, user, _| c == deal[:active_conversation_id] && user == deal[:assignee_id] }.map(&:last).max
    last = [deal[:last_activity_at], replied].compact.max || deal[:created_at]
    (@anchor - day(last)).to_i >= STALE_DAYS
  end

  def stale
    rows = open_deals
    stale = rows.select { |d| quiet?(d) }
    late = rows.select { |d| d[:close_date] && d[:close_date] < @anchor }
    entry('stale', 'manager', {}, 'totals.stale.count' => stale.size, 'totals.overdue.count' => late.size,
                                  'totals.at_risk.count' => (stale | late).size, 'totals.at_risk.total_cents' => cents(stale | late))
  end

  def tasks
    mine = tasks_rows.select { |row| row[0] == @first }
    end_of_day = @now.end_of_day
    from, to = dates(october)
    entry('my_tasks', 'employee', october,
          'totals.overdue_count' => mine.count { |r| r[2] == 'open' && r[3] && r[3] < @now },
          'totals.today_count' => mine.count { |r| r[2] == 'open' && r[3] && r[3] >= @now && r[3] <= end_of_day },
          'totals.done_count' => mine.count { |r| r[2] == 'done' && within(r[4], from, to) })
  end

  def results(rows, from, to)
    won = won_in(from, to, rows)
    lost = lost_in(from, to, rows)
    { 'totals.won_count' => won.size, 'totals.lost_count' => lost.size, 'totals.won_cents' => cents(won),
      'totals.lost_cents' => cents(lost), 'totals.by_count' => percent(won.size, won.size + lost.size),
      'totals.by_value' => percent(cents(won), cents(won) + cents(lost)) }
  end

  def won_lost
    [[october, nil], [october, @first], [quarter, nil]].map do |params, user|
      entry('won_lost', user ? 'employee' : 'manager', params, results(mine(deals, user), *dates(params)))
    end
  end

  def quota
    from, to = dates(october)
    [nil, @first].map do |user|
      won = cents(won_in(from, to, mine(deals, user)))
      goal = target(from, to, user)
      entry('quota', user ? 'employee' : 'manager', october,
            'totals.won_cents' => won, 'totals.target_cents' => goal, 'totals.attainment' => percent(won, goal))
    end
  end

  def category(deal)
    return 'commit' if probability(deal) >= 90
    return 'best_case' if probability(deal) >= 50

    'pipeline'
  end

  def forecast
    from, to = dates(next_month)
    rows = open_deals.select { |d| d[:close_date]&.between?(from, to) }
    by = rows.group_by { |d| category(d) }
    entry('forecast', 'manager', next_month,
          'totals.categories.commit.total_cents' => cents(by.fetch('commit', [])),
          'totals.categories.best_case.total_cents' => cents(by.fetch('best_case', [])),
          'totals.categories.pipeline.total_cents' => cents(by.fetch('pipeline', [])),
          'totals.won_cents' => cents(won_in(from, to)), 'totals.target_cents' => target(from, to))
  end

  def coverage
    from, to = dates(next_month)
    open = cents(open_deals.select { |d| d[:close_date]&.between?(from, to) })
    won = cents(won_in(from, to))
    goal = target(from, to)
    left = goal - won
    entry('coverage', 'manager', next_month, 'totals.open_cents' => open, 'totals.target_cents' => goal,
                                             'totals.coverage' => left.positive? ? (open.to_f / left).round(1) : nil)
  end

  def win_rate
    from, to = dates(october)
    won = won_in(from, to)
    lost = lost_in(from, to)
    expect = @seed.class::LISTS['product'].to_h do |name|
      w = won.count { |d| d[:product_id] == item(name) }
      l = lost.count { |d| d[:product_id] == item(name) }
      ["rows[name=#{name}].by_count", (w + l).positive? ? percent(w, w + l) : :absent]
    end
    entry('win_rate', 'manager', october.merge(group_by: 'product'), expect.reject { |_, v| v == :absent })
  end

  def losses
    lost = lost_in(*dates(quarter))
    expect = { 'totals.count' => lost.size, 'totals.total_cents' => cents(lost) }
    @seed.class::LISTS['competitor'].each do |name|
      count = lost.count { |d| d[:competitor_id] == item(name) }
      expect["competitors[name=#{name}].count"] = count if count.positive?
    end
    entry('losses', 'manager', quarter, expect)
  end

  def activity_of(user, from, to)
    tasks_rows.count { |r| r[0] == user && r[2] == 'done' && within(r[4], from, to) } +
      notes.count { |u, at| u == user && within(at, from, to) }
  end

  # Messages to customers: the employee's public replies in the period, in the active conversations of their own deals
  def messages_of(user, from, to)
    theirs = deals.filter_map { |d| d[:active_conversation_id] if d[:assignee_id] == user }
    @replies.count { |c, sender, at| sender == user && theirs.include?(c) && within(at, from, to) }
  end

  def activity
    from, to = dates(october)
    people = @seed.class::EMPLOYEES.each_index.map { |i| @seed.employee(i) }
    expect = people.to_h { |u| ["assignees[name=#{u.name}].activity_count", activity_of(u.id, from, to)] }
    people.each { |u| expect["assignees[name=#{u.name}].message_count"] = messages_of(u.id, from, to) }
    entry('activity', 'manager', october, expect.merge('totals.activity_count' => people.sum { |u| activity_of(u.id, from, to) },
                                                       'totals.message_count' => people.sum { |u| messages_of(u.id, from, to) }))
  end

  def new_deals
    from, to = dates(october)
    rows = deals.select { |d| within(d[:created_at], from, to) }
    expect = { 'totals.count' => rows.size, 'totals.total_cents' => cents(rows) }
    rows.group_by { |d| d[:lead_source_id] }.each do |id, group|
      expect["sources[name=#{names[id]}].count"] = group.size if id
    end
    entry('new_deals', 'manager', october, expect)
  end

  def data_quality
    rows = open_deals
    complete = rows.count { |d| d[:amount_cents].positive? && d[:close_date] && d[:assignee_id] }
    to_fix = rows.count do |d|
      !d[:amount_cents].positive? || d[:close_date].nil? || d[:close_date] < @anchor || d[:assignee_id].nil? || quiet?(d)
    end
    entry('data_quality', 'manager', {}, 'totals.open_count' => rows.size, 'totals.complete_count' => complete,
                                         'totals.rate' => percent(complete, rows.size), 'totals.to_fix' => to_fix)
  end

  def scorecard
    from, to = dates(october)
    cards = @seed.class::EMPLOYEES.each_index.map do |i|
      user = @seed.employee(i)
      rows = mine(deals, user.id)
      won = won_in(from, to, rows)
      lost = lost_in(from, to, rows)
      { name: user.name, attainment: percent(cents(won), target(from, to, user.id)),
        win_rate: percent(won.size, won.size + lost.size), new: rows.count { |d| within(d[:created_at], from, to) } }
    end
    expect = cards.each_with_object({}) do |card, out|
      out["cards[name=#{card[:name]}].attainment"] = card[:attainment]
      out["cards[name=#{card[:name]}].new_deal_count"] = card[:new]
    end
    known = cards.filter_map { |c| c[:attainment] }
    entry('scorecard', 'manager', october, expect.merge('team_average.attainment' => (known.sum / known.size).round(1)))
  end

  # ---- the log-based reports -----------------------------------------------------------------------------------

  def open_stage_ids = stages.select { |_, s| s[:kind] == 'open' }.sort_by { |_, s| s[:position] }.map(&:first)
  def won_stage_ids = stages.select { |_, s| s[:kind] == 'won' }.keys

  # The stages a deal was logged entering (creation, moves, reopening), plus the open ones it passed
  def reached(deal)
    seen = events.fetch(deal[:id], []).filter_map do |_, kind, data, _|
      (kind == 'created' ? data['stage_id'] : data['to_stage_id'])&.to_i if %w[created stage_changed reopened].include?(kind)
    end
    return seen | open_stage_ids if seen.intersect?(won_stage_ids)

    furthest = seen.filter_map { |id| open_stage_ids.index(id) }.max
    seen | (furthest ? open_stage_ids.first(furthest + 1) : [])
  end

  def conversion
    from, to = dates(quarter)
    created = deals.select { |d| within(d[:created_at], from, to) }
    expect = { 'created_count' => created.size }
    (open_stage_ids + won_stage_ids).each do |stage|
      expect["rows[name=#{stages[stage][:name]}].count"] = created.count { |d| reached(d).include?(stage) }
    end
    entry('conversion', 'manager', quarter, expect)
  end

  # [[stage, from, to]] for one deal: from its creation, each move closing the stay before it
  def stays(deal)
    list = events.fetch(deal[:id], [])
    moves = list.select { |_, kind, _, _| %w[stage_changed reopened].include?(kind) }
    first = list.find { |_, kind, _, _| kind == 'created' }&.dig(2, 'stage_id') || moves.first&.dig(2, 'from_stage_id') || deal[:stage_id]
    result = [[first.to_i, deal[:created_at], nil]]
    moves.each do |_, _, data, at|
      result.last[2] = at
      result << [data['to_stage_id'].to_i, at, nil]
    end
    result
  end

  def cycle
    from, to = dates(quarter)
    won = won_in(from, to)
    cycle = won.empty? ? nil : (won.sum { |d| d[:won_at] - d[:created_at] } / won.size / 1.day).round(1)
    ended = deals.select { |d| day(d[:created_at]) <= to }.flat_map { |d| stays(d) }
                 .select { |stage, _, out| out && within(out, from, to) && open_stage_ids.include?(stage) }
    expect = { 'cycle_days' => cycle }
    open_stage_ids.each do |stage|
      mine = ended.select { |s, _, _| s == stage }
      next if mine.empty?

      expect["stages[name=#{stages[stage][:name]}].average_days"] = (mine.sum { |_, a, b| (b - a) / 1.day } / mine.size).round(1)
    end
    entry('cycle', 'manager', quarter, expect)
  end

  def amount_at(deal, moment)
    changes = events.fetch(deal[:id], []).select { |_, kind, _, at| kind == 'amount_changed' && at > moment }
    # undo them newest first: the value then is the `from` of the earliest
    changes.reverse.reduce(deal[:amount_cents]) { |_, (_, _, data, _)| data['from'].to_i }
  end

  def changes
    from = @anchor - 6
    starts = ZONE.local(from.year, from.month, from.day)
    closed_before = ->(d) { [d[:won_at], d[:lost_at]].compact.any? { |at| at < starts } }
    start_value = deals.select { |d| d[:created_at] < starts && !closed_before.call(d) }.sum { |d| amount_at(d, starts) }
    params = { from: from.iso8601, to: @anchor.iso8601 }
    entry('changes', 'manager', params,
          'totals.waterfall.start' => start_value, 'totals.waterfall.end' => cents(open_deals),
          'totals.counts.new' => deals.count { |d| within(d[:created_at], from, @anchor) },
          'totals.counts.won' => won_in(from, @anchor).size, 'totals.counts.lost' => lost_in(from, @anchor).size)
  end

  def revenue
    from, to = dates(quarter)
    won = won_in(from, to)
    expect = { 'totals.won_cents' => cents(won) }
    won.group_by { |d| d[:product_id] }.each { |id, rows| expect["rows[name=#{names[id]}].total_cents"] = cents(rows) if id }
    entry('revenue', 'manager', quarter.merge(group_by: 'product'), expect)
  end

  def deal_size
    from = @anchor.beginning_of_month << 5
    params = { from: from.iso8601, to: @anchor.iso8601 }
    sized = won_in(from, @anchor).select { |d| d[:amount_cents].positive? }
    expect = { 'totals.average_cents' => sized.empty? ? nil : cents(sized) / sized.size }
    sized.group_by { |d| day(d[:won_at]).beginning_of_month }.each do |month, rows|
      expect["buckets[bucket=#{month.iso8601}].average_cents"] = cents(rows) / rows.size
    end
    entry('deal_size', 'manager', params, expect)
  end

  # ---- conversations and sales (CONVERSATION_SALES_PLAN.md, phase 4) ---------------------------------------------

  def whole_period = { from: (@anchor.beginning_of_month << 5).iso8601, to: @anchor.iso8601 }

  # 20: deals closed in the period whose conversation has a first reply, in buckets of the reply time (real seconds)
  def response_speed
    from, to = dates(whole_period)
    limits = { 'under_5m' => 0...300, '5_30m' => 300...1800, '30m_2h' => 1800...7200, '2h_24h' => 7200...86_400,
               'over_24h' => 86_400..Float::INFINITY }
    [nil, @first].map do |user|
      closed = (won_in(from, to, mine(deals, user)) + lost_in(from, to, mine(deals, user)))
      timed = closed.select { |d| d[:conversation_id] && @first_replies[d[:conversation_id]] }
      expect = { 'totals.closed_count' => timed.size, 'totals.excluded_count' => closed.size - timed.size }
      limits.each do |key, range|
        rows = timed.select { |d| range.cover?(@first_replies[d[:conversation_id]]) }
        won = rows.count { |d| d[:status] == 'won' }
        expect["buckets[key=#{key}].closed_count"] = rows.size
        expect["buckets[key=#{key}].won_count"] = won
        expect["buckets[key=#{key}].win_rate"] = rows.size < 10 ? nil : percent(won, rows.size)
      end
      entry('response_speed', user ? 'employee' : 'manager', whole_period, expect)
    end
  end

  # 21: deals created in the period credited to each campaign, direct and influenced apart; the SMS recipients and cost
  def campaigns
    from, to = dates(whole_period)
    credited = deals.select { |d| d[:campaign_id] && within(d[:created_at], from, to) }
    expect = {}
    credited.group_by { |d| d[:campaign_id] }.each do |id, rows|
      title = @campaigns[id]
      ATTRIBUTIONS.each do |kind|
        mine = rows.select { |d| d[:campaign_attribution].to_s == kind }
        won = mine.select { |d| d[:status] == 'won' }
        expect["rows[title=#{title}].#{kind}.count"] = mine.size
        expect["rows[title=#{title}].#{kind}.won_cents"] = cents(won)
      end
      sent = @recipients.select { |campaign, _| campaign == id }
      expect["rows[title=#{title}].recipients"] = sent.size
      expect["rows[title=#{title}].cost_known"] = sent.any? && sent.none? { |_, price| price.nil? }
    end
    entry('campaigns', 'manager', whole_period, expect)
  end

  # 22: the period's conversations, how many became a deal (once each) and the deals won, per inbox
  def conversation_deals
    from, to = dates(october)
    period = @conversations.select { |_, _, _, at| within(at, from, to) }
    from_deals = deals.select { |d| d[:conversation_id] }
    counts = lambda do |rows|
      ids = rows.map(&:first)
      became = from_deals.select { |d| ids.include?(d[:conversation_id]) }
      { conversations: rows.size, deals: became.map { |d| d[:conversation_id] }.uniq.size, won: became.count { |d| d[:status] == 'won' } }
    end
    all = counts.call(period)
    expect = { 'totals.conversation_count' => all[:conversations], 'totals.deal_count' => all[:deals], 'totals.won_count' => all[:won] }
    period.group_by { |_, inbox, _, _| inbox }.each do |inbox, rows|
      figures = counts.call(rows)
      expect["inboxes[name=#{@inbox_names[inbox]}].conversation_count"] = figures[:conversations]
      expect["inboxes[name=#{@inbox_names[inbox]}].deal_count"] = figures[:deals]
    end
    entry('conversation_deals', 'manager', october, expect)
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
