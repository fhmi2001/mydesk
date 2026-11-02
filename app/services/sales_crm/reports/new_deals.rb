# Custom (MyDesk): التقرير 15, الصفقات الجديدة حسب المصدر: how many deals were created in the period, worth what, and where
# they came from (lead source; «no source» when none was picked). Over the period by day, week or month, against the
# period before, and in the team view per employee and source.
class SalesCrm::Reports::NewDeals < SalesCrm::Reports::Report
  KEY = 'new_deals'.freeze

  def self.list_filters = %i[product_id lead_source_id]

  def build
    totals = figures(created(period))
    { totals: totals, previous_totals: figures(created(period.previous)), empty: totals[:count].zero?, interval: interval,
      sources: sources, buckets: buckets, assignees: assignees }
  end

  # cell: any of lead_source_id ('none' too), assignee_id and from / to (a bucket)
  def drill_scope(cell) = by_lists(by_assignee(created(window_for(cell)), cell), cell)

  private

  def drill_order = { created_at: :desc, id: :desc }

  def created(window) = deals.where(created_at: window.range)

  def figures(relation)
    count, cents = relation.pick(Arel.sql('COUNT(*)'), Arel.sql('COALESCE(SUM(crm_deals.amount_cents), 0)'))
    { count: count, total_cents: cents.to_i }
  end

  # [[source id, assignee id, count, cents]] for the period
  def groups
    @groups ||= created(period).group(:lead_source_id, :assignee_id)
                               .pluck(:lead_source_id, :assignee_id, Arel.sql('COUNT(*)'), Arel.sql('SUM(crm_deals.amount_cents)'))
  end

  def source_names = @source_names ||= item_names(groups.map(&:first))

  # Count and value of some [source, assignee, count, cents] groups
  def add_up(rows) = { count: rows.sum { |r| r[2] }, total_cents: rows.sum { |r| r[3].to_i } }

  def sources
    result = groups.group_by(&:first).map do |source, rows|
      add_up(rows).merge(lead_source_id: source, name: source_names[source], cell: { lead_source_id: source || NONE })
    end
    result.sort_by { |s| [-s[:count], -s[:total_cents]] }
  end

  def buckets
    sums = created(period).pluck(:created_at, :amount_cents).each_with_object(Hash.new { |h, k| h[k] = [0, 0] }) do |(at, cents), acc|
      bucket = acc[bucket_start(local_date(at))]
      bucket[0] += 1
      bucket[1] += cents
    end
    bucket_cells.map do |start, cell|
      count, cents = sums.fetch(start, [0, 0])
      { bucket: start.iso8601, count: count, total_cents: cents, cell: cell }
    end
  end

  # Per employee: their new deals, split by source
  def assignees
    return nil unless team_view?

    people = names(groups.map(&:second))
    result = groups.group_by(&:second).map do |id, rows|
      add_up(rows).merge(assignee_id: id, name: people[id], cell: assignee_cell(id), sources: rows.map { |row| source_of(id, row) })
    end
    result.sort_by { |row| -row[:count] }
  end

  def source_of(id, (source, _, count, cents))
    { lead_source_id: source, count: count, total_cents: cents.to_i, cell: assignee_cell(id).merge(lead_source_id: source || NONE) }
  end
end
