# Custom (MyDesk): the Sales reports' demo account and reference numbers (CRM_REPORTS_PLAN.md), for
# development only.
#   rails sales_crm:demo_seed                      # data up to today
#   ANCHOR=2026-10-31 rails sales_crm:demo_seed    # data up to a given day
#   ADMIN_EMAIL=you@example.com rails ...          # also make an existing user a manager of the demo account
#   rails sales_crm:expected_numbers               # rewrite docs/reports/expected_numbers.yml
# New users get random passwords, written to tmp/sales_crm_demo_credentials.txt (never printed, never committed).
# The demo data and its reference numbers sit under db/seeds/sales_crm, outside the app's load paths; each task
# requires them once the app is loaded.
namespace :sales_crm do
  desc 'Create or refresh the Sales reports demo account (development only)'
  task demo_seed: :environment do
    abort 'sales_crm:demo_seed runs in development only' unless Rails.env.development?

    require Rails.root.join('db/seeds/sales_crm/demo_seed').to_s

    anchor = ENV['ANCHOR'].present? ? Date.iso8601(ENV.fetch('ANCHOR')) : SalesCrm::Period.today
    seed = SalesCrm::DemoSeed.new(anchor: anchor, passwords: true).perform
    if ENV['ADMIN_EMAIL'].present?
      user = User.find_by!(email: ENV.fetch('ADMIN_EMAIL'))
      AccountUser.find_or_create_by!(account: seed.account, user: user) { |au| au.role = :administrator }
    end
    path = Rails.root.join('tmp/sales_crm_demo_credentials.txt')
    File.write(path, "#{seed.passwords.map { |email, password| "#{email}\t#{password}" }.join("\n")}\n")
    File.chmod(0o600, path)
    puts "Demo account ##{seed.account.id} (#{seed.account.name}): #{seed.account.crm_deals.count} deals up to #{anchor}. " \
         "Sign-in details: #{path.relative_path_from(Rails.root)}"
  end
end

namespace :sales_crm do
  # The same data in an existing account, beside what is already there (nothing is cleared), with a sales manager and
  # four employees named for that account's domain. Runs once per account.
  #   ACCOUNT_ID=2 DOMAIN=bajaba.test rails sales_crm:populate
  desc 'Fill an existing account with six months of sales data and a sales team (development only)'
  task populate: :environment do
    abort 'sales_crm:populate runs in development only' unless Rails.env.development?

    require Rails.root.join('db/seeds/sales_crm/demo_seed').to_s

    account = Account.find(ENV.fetch('ACCOUNT_ID'))
    domain = ENV.fetch('DOMAIN')
    locals = %w[sara.alotaibi khalid.alshehri noura.alqahtani fahad.aldosari]
    people = { manager: { name: 'عبدالله الحربي', email: "abdullah.alharbi@#{domain}" }, emails: locals.map { |l| "#{l}@#{domain}" } }
    abort "Account ##{account.id} already has this sales team" if account.users.exists?(email: people[:emails].first)

    seed = SalesCrm::DemoSeed.new(anchor: SalesCrm::Period.today, passwords: true, account: account, people: people).perform
    path = Rails.root.join("tmp/sales_crm_account_#{account.id}_credentials.txt")
    File.write(path, "#{seed.passwords.map { |email, password| "#{email}\t#{password}" }.join("\n")}\n")
    File.chmod(0o600, path)
    puts "Account ##{account.id} (#{account.name}): #{account.crm_deals.count} deals in all. Sign-in details: " \
         "#{path.relative_path_from(Rails.root)}"
  end
end

namespace :sales_crm do
  # The demo data up to 2026-10-31 is built inside a transaction that is rolled back, so nothing stays behind, and
  # worked out by SalesCrm::ExpectedNumbers, apart from the app
  desc 'Write docs/reports/expected_numbers.yml from the demo data (development only)'
  task expected_numbers: :environment do
    abort 'sales_crm:expected_numbers runs in development only' unless Rails.env.development?

    require Rails.root.join('db/seeds/sales_crm/demo_seed').to_s
    require Rails.root.join('db/seeds/sales_crm/expected_numbers').to_s
    anchor = Date.iso8601(ENV.fetch('ANCHOR', '2026-10-31'))
    entries = nil
    ActiveRecord::Base.transaction do
      entries = SalesCrm::ExpectedNumbers.new(SalesCrm::DemoSeed.new(anchor: anchor).perform).entries
      raise ActiveRecord::Rollback
    end
    path = Rails.root.join('docs/reports/expected_numbers.yml')
    header = "# Custom (MyDesk): the Sales reports' reference numbers for the demo data up to #{anchor}, worked out by\n" \
             "# db/seeds/sales_crm/expected_numbers.rb apart from the app. Regenerate: rails sales_crm:expected_numbers\n"
    File.write(path, header + { 'anchor' => anchor.iso8601, 'checks' => entries }.to_yaml.delete_prefix("---\n"))
    puts "#{entries.size} checks, #{entries.sum { |e| e['expect'].size }} numbers → #{path.relative_path_from(Rails.root)}"
  end
end
