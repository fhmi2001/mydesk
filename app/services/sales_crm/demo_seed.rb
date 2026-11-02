# Custom (MyDesk): demo data for the Sales reports (CRM_REPORTS_PLAN.md, phase 6). One account, a manager and four
# employees, about 200 deals over the six months up to `anchor` with their whole history in the activity log (created,
# moves between stages days apart, value changes, pushed close dates, won and lost), tasks done and late, notes, and a
# monthly target per employee; in the demo account, conversations too (SalesCrm::DemoConversations). Everything comes
# from one seeded random generator and dates relative to `anchor`, so
# the same anchor always gives the same data: docs/reports/expected_numbers.yml is checked against it
# (spec/services/sales_crm/reports/catalog_acceptance_spec.rb). Records are written directly, with their past timestamps; the
# services would stamp them now.
# rubocop:disable Metrics/ClassLength, Metrics/AbcSize, Metrics/ParameterLists, Metrics/CyclomaticComplexity, Rails/SkipsModelValidations -- demo data built step by step, written straight to the tables with its past timestamps
class SalesCrm::DemoSeed
  ACCOUNT_NAME = 'MyDesk تجريبي'.freeze
  MANAGER = { name: 'مدير المبيعات', email: 'demo-manager@mydesk.test' }.freeze
  EMPLOYEES = [
    { name: 'سارة العتيبي', email: 'demo-agent-1@mydesk.test', share: 0.32, monthly_target: 250_000 },
    { name: 'خالد الشهري', email: 'demo-agent-2@mydesk.test', share: 0.28, monthly_target: 200_000 },
    { name: 'نورة القحطاني', email: 'demo-agent-3@mydesk.test', share: 0.24, monthly_target: 180_000 },
    { name: 'فهد الدوسري', email: 'demo-agent-4@mydesk.test', share: 0.16, monthly_target: 120_000 }
  ].freeze
  LISTS = {
    'product' => ['باقة الرسائل', 'باقة الواتساب', 'نظام المتجر', 'الاستشارات'],
    'region' => %w[الرياض جدة الدمام],
    'industry' => %w[التجزئة الصحة التعليم],
    'competitor' => ['منافس أ', 'منافس ب', 'منافس ج']
  }.freeze
  LOST_REASONS = ['السعر مرتفع', 'اختار منافساً', 'لا يوجد ميزانية', 'لم يرد العميل'].freeze
  DEALS = 200
  DAYS = 182
  SEED = 20_261_031

  # The customers the deals are with: a Chatwoot contact each (company names from these parts, a Saudi mobile number)
  COMPANY_KINDS = %w[مؤسسة شركة متجر مجموعة مركز].freeze
  COMPANY_NAMES = %w[النخبة الأفق الريادة السنابل الواحة الرواد البيان الإتقان المسار الصفوة الأصالة النجوم الفجر الخليج
                     الندى الإبداع التميز الجزيرة الرياض المدار الأمل الوفاء الرؤية المستقبل].freeze
  CUSTOMERS = 120
  NOTES = ['تم الاتصال بالعميل وطلب عرض سعر محدّث', 'العميل يقارن مع منافس، يحتاج متابعة الأسبوع القادم',
           'تم إرسال العرض بالبريد', 'اجتماع مثمر، العميل مهتم بالباقة السنوية', 'بانتظار موافقة الإدارة لدى العميل',
           'طلب العميل تجربة مجانية'].freeze

  attr_reader :account, :anchor, :passwords

  # anchor: the last day of the data (a Date); passwords: true to set new random passwords and return them.
  # account: fill this existing account instead of the demo one; its own data stays (nothing is cleared).
  # people: { manager: { name:, email: }, emails: [4 employee emails] } to name the users otherwise.
  def initialize(anchor:, passwords: false, account: nil, people: nil)
    @anchor = anchor
    @rng = Random.new(SEED)
    # Names and words come from their own generator, so they never change the numbers drawn from @rng
    @words = Random.new(SEED + 1)
    @set_passwords = passwords
    @passwords = {}
    @target = account
    @people = people || {}
  end

  def perform
    ActiveRecord::Base.transaction do
      @account = @target || Account.find_or_create_by!(name: ACCOUNT_NAME)
      account.enable_features!('sales_crm')
      clear unless @target
      people
      lists
      @pipeline = SalesCrm::Pipelines::EnsureDefault.call(account)
      targets
      customers
      DEALS.times { |index| deal(index) }
      tasks_and_notes
      # Demo conversations, replies, campaigns and suggestions: in the demo account only, never in a real one
      SalesCrm::DemoConversations.new(self).perform unless @target
    end
    self
  end

  def manager = @users.fetch(manager_person[:email])
  def employee(index) = @users.fetch(employee_people[index][:email])

  def manager_person = MANAGER.merge(@people[:manager] || {})

  def employee_people
    EMPLOYEES.each_with_index.map { |person, i| @people[:emails] ? person.merge(email: @people[:emails][i]) : person }
  end

  # An agent is offered to take a conversation only in the inboxes they belong to (Inbox#assignable_agents), so the
  # sales team joins every inbox of the account; administrators are offered everywhere already
  def self.give_inbox_access(account, users)
    account.inboxes.find_each do |inbox|
      users.each { |user| InboxMember.find_or_create_by!(inbox: inbox, user: user) }
    end
  end

  private

  def zone = SalesCrm::TimeZone.for(account)
  def at(date, hour = 10, minute = 0) = zone.local(date.year, date.month, date.day, hour, minute)
  def first_day = anchor - DAYS + 1
  # Nothing happens after 17:00 on the anchor day (the checks look at the data from 18:00 that day)
  def cutoff = at(anchor, 17)
  def pick(list) = list[@rng.rand(list.size)]
  def chance?(share) = @rng.rand < share

  # A fresh start: the account's Sales data goes, its users and settings stay
  def clear
    SalesCrm::DemoConversations.clear(account)
    %i[crm_activities crm_notes crm_tasks crm_deals crm_targets contacts].each { |records| account.public_send(records).delete_all }
    account.reload # delete_all leaves those associations loaded and empty; the rows written next must be read afresh
  end

  def people
    @users = {}
    ([manager_person.merge(role: :administrator)] + employee_people.map { |e| e.merge(role: :agent) }).each do |person|
      user = User.find_or_initialize_by(email: person[:email])
      user.name = person[:name]
      if user.new_record? || @set_passwords
        password = "#{SecureRandom.base58(14)}a1!"
        user.password = password
        @passwords[person[:email]] = password if @set_passwords
      end
      user.confirmed_at ||= Time.current
      user.save!
      AccountUser.find_or_create_by!(account: account, user: user) { |au| au.role = person[:role] }.update!(role: person[:role])
      @users[person[:email]] = user
    end
    self.class.give_inbox_access(account, @users.values)
  end

  def lists
    SalesCrm::ListItem.ensure_defaults!(account, 'lead_source')
    @items = SalesCrm::ListItem::LISTS.index_with do |list|
      names = LISTS[list]
      names&.each_with_index { |name, i| account.crm_list_items.find_or_create_by!(list: list, name: name) { |item| item.position = i } }
      account.crm_list_items.active.where(list: list).order(:position, :id).to_a
    end
  end

  # A monthly target per employee for each month of the data and the one after it
  def targets
    month = first_day.beginning_of_month
    while month <= anchor.next_month.beginning_of_month
      EMPLOYEES.each_with_index do |person, i|
        account.crm_targets.create!(user: employee(i), period_start: month, period_end: month.end_of_month,
                                    amount_cents: person[:monthly_target] * 100)
      end
      month = month.next_month
    end
  end

  # The customers, as Chatwoot contacts (no callbacks: nothing to notify about a contact that never wrote)
  def customers
    names = COMPANY_KINDS.product(COMPANY_NAMES).map { |kind, name| "#{kind} #{name}" }.sample(CUSTOMERS, random: @words)
    stamp = at(first_day - 30)
    rows = names.each_with_index.map do |name, i|
      { account_id: account.id, name: name, phone_number: "+9665#{format('%08d', 10_000_000 + (i * 7_919) + @words.rand(7_000))}",
        contact_type: Contact.contact_types['customer'], created_at: stamp, updated_at: stamp }
    end
    @customers = Contact.insert_all(rows, returning: %w[id name]).rows
  end

  def owner_index
    roll = @rng.rand
    EMPLOYEES.each_with_index { |person, i| return i if (roll -= person[:share]) <= 0 }
    EMPLOYEES.size - 1
  end

  def open_stages = @pipeline.stages.select(&:open?)

  # One deal and its history
  def deal(_index)
    owner = employee(owner_index)
    created_on = first_day + @rng.rand(DAYS - 2)
    created = at(created_on, 8 + @rng.rand(10), @rng.rand(60))
    amount = (5 + @rng.rand(146)) * 1_000 * 100
    attrs = deal_attributes(owner, created, amount)
    record = account.crm_deals.create!(attrs.merge(customer(attrs[:product_id])))
    history(record, owner, created, amount)
  end

  # The deal's customer and a title naming what is sold to whom («باقة الواتساب — مؤسسة النخبة»)
  def customer(product_id)
    contact_id, name = @customers[@words.rand(@customers.size)]
    offer = @items['product'].find { |item| item.id == product_id }&.name || 'خدمات الحلول'
    { contact_id: contact_id, contact_name_snapshot: name, title: "#{offer} — #{name}" }
  end

  def deal_attributes(owner, created, amount)
    { pipeline: @pipeline, stage: open_stages.first, assignee: owner, creator: owner,
      amount_cents: amount, currency: 'SAR', status: :open, created_at: created, updated_at: created,
      lead_source_id: chance?(0.9) ? pick(@items['lead_source']).id : nil,
      product_id: chance?(0.92) ? pick(@items['product']).id : nil,
      region_id: chance?(0.85) ? pick(@items['region']).id : nil,
      industry_id: chance?(0.85) ? pick(@items['industry']).id : nil,
      close_date: created.to_date + 20 + @rng.rand(60) }
  end

  # Moves through the open stages days apart, then maybe a win or a loss; whatever would fall after the anchor stays
  # in the future, and the deal is left where it stood at the anchor
  def history(record, owner, created, amount)
    events = [[created, 'created', { stage_id: open_stages.first.id }]] unless chance?(0.05) # a few from before the log
    events ||= []
    now = created
    stage = open_stages.first
    target = outcome
    reach = if target == :open
              @rng.rand(open_stages.size)
            else
              (target == :won ? open_stages.size - 1 : @rng.rand(open_stages.size))
            end
    open_stages[1..reach].each do |next_stage|
      now += (1 + @rng.rand(12)).days + @rng.rand(8).hours
      break if now > cutoff

      events << [now, 'stage_changed', { from_stage_id: stage.id, to_stage_id: next_stage.id }]
      stage = next_stage
    end
    finish(record, owner, events, stage, now, target, amount)
  end

  def outcome
    roll = @rng.rand
    return :won if roll < 0.36
    return :lost if roll < 0.62

    :open
  end

  def finish(record, owner, events, stage, now, target, amount)
    attrs = { stage: stage }
    closed_at = now + (1 + @rng.rand(10)).days
    if target != :open && closed_at <= cutoff
      closing = target == :won ? @pipeline.won_stage : @pipeline.lost_stage
      events << [closed_at, 'stage_changed', { from_stage_id: stage.id, to_stage_id: closing.id }]
      attrs.merge!(closed(target, closing, closed_at))
    end
    changes(record, events, attrs, amount, now)
    attrs[:last_activity_at] = events.map(&:first).max || record.created_at
    # The stale reports read the last touch (Metrics::DaysSinceActivity); no reply in a conversation is seeded yet
    attrs[:last_touch_at] = attrs[:last_activity_at]
    record.update_columns(attrs.merge(stage_id: attrs.delete(:stage).id))
    log(record, owner, events)
  end

  def closed(target, _closing, closed_at)
    return { status: :won, won_at: closed_at } if target == :won

    { status: :lost, lost_at: closed_at, lost_reason: pick(LOST_REASONS),
      competitor_id: chance?(0.6) ? pick(@items['competitor']).id : nil }
  end

  # Some deals had their value or their close date changed along the way; a few open ones miss data
  def changes(record, events, attrs, amount, now)
    if chance?(0.18)
      changed_at = record.created_at + ((now - record.created_at) * @rng.rand)
      first = amount + ((@rng.rand(41) - 20) * 1_000 * 100)
      events << [changed_at, 'amount_changed', { from: [first, 100_000].max, to: amount }] if changed_at <= cutoff
    end
    if chance?(0.2)
      moved_at = record.created_at + ((now - record.created_at) * @rng.rand)
      was = record.close_date - (10 + @rng.rand(30))
      events << [moved_at, 'close_date_changed', { from: was.iso8601, to: record.close_date.iso8601 }] if moved_at <= cutoff
    end
    return unless attrs[:status].nil?

    attrs[:close_date] = nil if chance?(0.04)
    attrs[:amount_cents] = 0 if chance?(0.03)
  end

  def log(record, owner, events)
    rows = events.sort_by(&:first).map do |time, kind, data|
      { account_id: account.id, deal_id: record.id, user_id: owner.id, kind: kind, data: data, created_at: time }
    end
    SalesCrm::Activity.insert_all(rows) if rows.any?
  end

  # Tasks over the six months (most done, some late, some due today and later), and notes on deals
  def tasks_and_notes
    deals = account.crm_deals.order(:id).pluck(:id, :assignee_id) # in a fixed order, so every database picks the same
    tasks = Array.new(240) { task_row(deals) }
    SalesCrm::Task.insert_all(tasks)
    notes = Array.new(120) do
      deal_id, owner_id = pick(deals)
      written = at(first_day + @rng.rand(DAYS), 9 + @rng.rand(9))
      { account_id: account.id, deal_id: deal_id, user_id: owner_id, content: NOTES[@words.rand(NOTES.size)], created_at: written,
        updated_at: written }
    end
    SalesCrm::Note.insert_all(notes)
  end

  def task_row(deals)
    deal_id, owner_id = pick(deals)
    due = at(first_day + @rng.rand(DAYS + 14), 9 + @rng.rand(13)) # until 21:00, so some fall due later on the anchor day
    done = due.to_date < anchor && chance?(0.8)
    done_at = done ? [due + @rng.rand(48).hours, at(anchor, 17)].min : nil
    { account_id: account.id, title: pick(['اتصال متابعة', 'إرسال عرض السعر', 'اجتماع تعريفي', 'تأكيد الدفع']),
      kind: SalesCrm::Task.kinds[pick(%w[task call meeting])], status: SalesCrm::Task.statuses[done ? 'done' : 'open'],
      due_at: due, done_at: done_at, assignee_id: owner_id, creator_id: owner_id, deal_id: deal_id,
      created_at: due - 3.days, updated_at: due - 3.days }
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/AbcSize, Metrics/ParameterLists, Metrics/CyclomaticComplexity, Rails/SkipsModelValidations
