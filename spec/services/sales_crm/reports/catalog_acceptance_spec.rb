# Custom (MyDesk): the acceptance check of CRM_REPORTS_PLAN.md. The demo data (SalesCrm::DemoSeed, about 200
# deals over six months with their whole log) is built as it stood at 18:00 on the anchor day, and every report is
# run on it:
# - each number in docs/reports/expected_numbers.yml, worked out apart from the app (db/seeds/sales_crm/expected_numbers.rb),
#   must come out the same;
# - in every report with a row per employee, the employees add up to the team;
# - the deals behind a number add up to it.
require 'rails_helper'
require Rails.root.join('db/seeds/sales_crm/demo_seed').to_s

RSpec.describe SalesCrm::Reports::Catalog do
  expected = YAML.load_file(Rails.root.join('docs/reports/expected_numbers.yml'))
  anchor = Date.iso8601(expected['anchor'])
  seeded = {}

  # Built once for the whole file: seeding takes a few seconds
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll -- one seeded account read by every example, removed after
    travel_to(ActiveSupport::TimeZone['Asia/Riyadh'].local(anchor.year, anchor.month, anchor.day, 18))
    seeded[:seed] = SalesCrm::DemoSeed.new(anchor: anchor).perform
  end

  # Seeding runs outside the per-example transaction, so its rows are removed here; nothing to remove if it failed
  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    next unless seeded[:seed]

    account = seeded[:seed].account
    users = account.users.to_a
    account.destroy!
    users.each(&:destroy!)
  end

  let(:seed) { seeded[:seed] }

  around { |example| travel_to(ActiveSupport::TimeZone['Asia/Riyadh'].local(anchor.year, anchor.month, anchor.day, 18)) { example.run } }

  def user_for(role) = role == 'employee' ? seed.employee(0) : seed.manager

  def report(key, role, params = {})
    described_class.fetch(key).new(account: seed.account, user: user_for(role), **params.symbolize_keys)
  end

  # `totals.won_count`, `rows[name=X].by_count`: hashes by key, arrays by the row whose field has that value
  def dig_path(data, path)
    path.split('.').reduce(data) do |node, part|
      name, field, value = part.match(/\A([^\[]+)(?:\[(\w+)=(.+)\])?\z/).captures
      # key? rather than ||, so a false value is read as false, not as missing
      found = node && (node.key?(name.to_sym) ? node[name.to_sym] : node[name])
      field ? Array(found).find { |row| (row[field.to_sym] || row[field]).to_s == value } : found
    end
  end

  expected['checks'].each do |check|
    it "matches the reference numbers of #{check['report']} for the #{check['as']} #{check['params'].presence || ''}" do
      result = report(check['report'], check['as'], check['params']).perform
      actual = check['expect'].keys.index_with { |path| dig_path(result, path) }
      expect(actual).to eq(check['expect'])
    end
  end

  # [report, params, the totals path, the employee rows' field]
  team_sums = [
    ['pipeline_by_stage', {}, 'totals.count', :count],
    ['closing', { from: '2026-11-01', to: '2026-11-30' }, 'totals.total_cents', :total_cents],
    ['won_lost', { from: '2026-10-01', to: '2026-10-31' }, 'totals.won_cents', :won_cents],
    ['quota', { from: '2026-10-01', to: '2026-10-31' }, 'totals.won_cents', :won_cents],
    ['coverage', { from: '2026-11-01', to: '2026-11-30' }, 'totals.open_cents', :open_cents],
    ['losses', { from: '2026-07-01', to: '2026-09-30' }, 'totals.count', :count],
    ['new_deals', { from: '2026-10-01', to: '2026-10-31' }, 'totals.count', :count],
    ['activity', { from: '2026-10-01', to: '2026-10-31' }, 'totals.activity_count', :activity_count],
    ['activity', { from: '2026-10-01', to: '2026-10-31' }, 'totals.message_count', :message_count],
    ['conversation_deals', { from: '2026-10-01', to: '2026-10-31' }, 'totals.conversation_count', :conversation_count]
  ]

  team_sums.each do |key, params, total, field|
    it "adds the employees of #{key} up to the team" do
      result = report(key, 'manager', params).perform
      expect(result[:assignees].sum { |row| row[field] }).to eq(dig_path(result, total))
    end
  end

  it 'adds the deals behind a number up to it' do
    [['pipeline_by_stage', {}, {}, 'totals.count'],
     ['closing', { from: '2026-11-01', to: '2026-11-30' }, {}, 'totals.count'],
     ['won_lost', { from: '2026-07-01', to: '2026-09-30' }, { status: 'won' }, 'totals.won_count'],
     ['new_deals', { from: '2026-10-01', to: '2026-10-31' }, {}, 'totals.count'],
     # Custom (MyDesk): the conversation reports (CONVERSATION_SALES_PLAN.md)
     ['response_speed', { from: '2026-05-01', to: '2026-10-31' }, { bucket: 'under_5m' }, 'buckets[key=under_5m].closed_count'],
     ['conversation_deals', { from: '2026-10-01', to: '2026-10-31' }, {}, 'totals.deal_count']].each do |key, params, cell, path|
      count = dig_path(report(key, 'manager', params).perform, path)
      drilled = report(key, 'manager', params.merge(cell: cell))
      expect(drilled.drill[:total_count]).to eq(count), key
    end
  end
end
