# Custom (MyDesk): the reports that join conversations and sales (docs/mydesk/CONVERSATION_SALES_PLAN.md, phase 4):
# 20 response speed and win rate, 21 campaign return, 22 conversation to deal. "Today" is 20 October 2026, 10:00 in
# Riyadh; the period is October so far. Expected numbers are worked out in the comments.
require 'rails_helper'

RSpec.describe SalesCrm::Reports::Catalog do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let(:riyadh) { ActiveSupport::TimeZone['Asia/Riyadh'] }

  around { |example| travel_to(ActiveSupport::TimeZone['Asia/Riyadh'].local(2026, 10, 20, 10, 0)) { example.run } }

  def day(month, date) = riyadh.local(2026, month, date)
  def run(key, user, **filters) = SalesCrm::Reports::Catalog.fetch(key).new(account: account, user: user, **filters).perform

  def drill(key, user, cell, **filters)
    SalesCrm::Reports::Catalog.fetch(key).new(account: account, user: user, cell: cell, **filters).drill
  end

  def deal(attrs = {})
    create(:crm_deal, { account: account, pipeline: pipeline, stage: pipeline.stages.find(&:open?), assignee: agent,
                        close_date: Date.new(2026, 11, 30) }.merge(attrs))
  end

  def closed(won, cents, at, **attrs)
    status = if won
               { status: :won, stage: pipeline.won_stage,
                 won_at: at }
             else
               { status: :lost, stage: pipeline.lost_stage, lost_at: at, lost_reason: 'x' }
             end
    deal(amount_cents: cents, **status, **attrs)
  end

  def answered_in(seconds, conversation = create(:conversation, account: account))
    ReportingEvent.create!(account: account, conversation: conversation, inbox: conversation.inbox, name: 'first_response',
                           value: seconds, value_in_business_hours: seconds)
    conversation
  end

  describe 'report 20, response speed and win rate' do
    before do
      # Under 5 minutes: 2 won (100 and 300), 1 lost → 3 closed, win rate 66.7%, average won 200
      closed(true, 10_000, day(10, 5), conversation: answered_in(60))
      closed(true, 30_000, day(10, 6), conversation: answered_in(200))
      closed(false, 50_000, day(10, 7), conversation: answered_in(120))
      # Over 24 hours: 1 lost
      closed(false, 20_000, day(10, 8), conversation: answered_in(90_000))
      # Left out: no conversation, a conversation without a reply yet, and a colleague's deal for the employee
      closed(true, 40_000, day(10, 9))
      closed(true, 40_000, day(10, 9), conversation: create(:conversation, account: account))
      closed(true, 70_000, day(10, 10), conversation: answered_in(60), assignee: colleague)
      # Closed in September: not in the period
      closed(true, 90_000, day(9, 20), conversation: answered_in(60))
    end

    it 'puts the closed deals in buckets by the first reply in their conversation' do
      result = run('response_speed', admin)
      fast = result[:buckets].find { |b| b[:key] == 'under_5m' }
      expect(fast).to include(closed_count: 4, won_count: 3, won_cents: 110_000, small_sample: true)
      expect(result[:buckets].map { |b| b[:key] }).to eq(%w[under_5m 5_30m 30m_2h 2h_24h over_24h])
      expect(result[:buckets].last).to include(closed_count: 1, won_count: 0)
      expect(result[:totals]).to include(closed_count: 5, excluded_count: 2)
    end

    it 'gives the rate only from 10 deals in a bucket' do
      6.times { |i| closed(true, 1_000, day(10, 11), conversation: answered_in(30 + i)) }
      fast = run('response_speed', admin)[:buckets].first
      expect(fast).to include(closed_count: 10, won_count: 9, win_rate: 90.0, small_sample: false)
    end

    it 'gives an employee their own deals only, and lists the deals of a bucket' do
      fast = run('response_speed', agent)[:buckets].first
      expect(fast).to include(closed_count: 3, won_count: 2)
      expect(drill('response_speed', agent, { bucket: 'under_5m' })[:total_count]).to eq(3)
    end
  end

  describe 'report 21, campaign return' do
    let(:sms) { create(:campaign, account: account, title: 'عرض نوفمبر') }
    let(:chat) { create(:campaign, account: account, title: 'ترحيب الموقع') }

    before do
      %w[966500000001 966500000002 966500000003 966500000004].each_with_index do |phone, i|
        SmsCampaignRecipient.create!(account: account, campaign: sms, phone_number: phone, status: :sent, sent_at: day(10, 1),
                                     delivery_price: i < 3 ? 0.05 : nil)
      end
      # SMS: 2 influenced deals created in October, one won (1,000 SAR)
      closed(true, 100_000, day(10, 10), campaign: sms, campaign_attribution: :influenced, created_at: day(10, 3))
      deal(campaign: sms, campaign_attribution: :influenced, created_at: day(10, 4))
      # Live chat: 1 direct deal, won (500 SAR)
      closed(true, 50_000, day(10, 12), campaign: chat, campaign_attribution: :direct, created_at: day(10, 5))
      # Created in September: not in the period
      deal(campaign: sms, campaign_attribution: :influenced, created_at: day(9, 25))
    end

    it 'credits each campaign with its deals and revenue, direct and influenced apart, with the SMS cost' do
      rows = run('campaigns', admin)[:rows].index_by { |r| r[:campaign_id] }
      expect(rows[sms.id]).to include(title: 'عرض نوفمبر', recipients: 4, cost_known: false)
      expect(rows[sms.id][:influenced]).to include(count: 2, won_count: 1, won_cents: 100_000)
      expect(rows[sms.id][:direct]).to include(count: 0)
      expect(rows[sms.id][:conversion]).to eq(50.0) # 2 deals from 4 recipients
      expect(rows[sms.id][:cost]).to eq(0.15) # 3 known prices; one unknown
      expect(rows[chat.id][:direct]).to include(count: 1, won_count: 1, won_cents: 50_000)
      expect(drill('campaigns', admin, { campaign_id: sms.id, attribution: 'influenced' })[:total_count]).to eq(2)
    end

    it 'is for the manager only' do
      expect(described_class.fetch('campaigns').admin_only?).to be(true)
    end
  end

  describe 'report 22, conversation to deal' do
    let(:web) { create(:inbox, account: account, name: 'الموقع') }
    let(:sms_inbox) { create(:inbox, account: account, name: 'SMS') }

    before do
      first = create(:conversation, account: account, inbox: web, assignee: agent, created_at: day(10, 2))
      second = create(:conversation, account: account, inbox: web, assignee: agent, created_at: day(10, 3))
      create(:conversation, account: account, inbox: web, assignee: colleague, created_at: day(10, 4))
      create(:conversation, account: account, inbox: sms_inbox, assignee: agent, created_at: day(10, 6))
      create(:conversation, account: account, inbox: web, created_at: day(9, 20)) # September: left out
      closed(true, 80_000, day(10, 9), conversation: first)
      deal(conversation: second)
    end

    it 'counts the conversations of the period, those that became a deal and those won, per channel' do
      result = run('conversation_deals', admin)
      expect(result[:totals]).to include(conversation_count: 4, deal_count: 2, won_count: 1, won_cents: 80_000, conversion: 50.0)
      by_inbox = result[:inboxes].index_by { |r| r[:name] }
      expect(by_inbox['الموقع']).to include(conversation_count: 3, deal_count: 2, won_count: 1, conversion: 66.7)
      expect(by_inbox['SMS']).to include(conversation_count: 1, deal_count: 0)
      expect(drill('conversation_deals', admin, { inbox_id: web.id })[:total_count]).to eq(2)
    end

    it 'gives an employee the conversations assigned to them and their own deals' do
      expect(run('conversation_deals', agent)[:totals]).to include(conversation_count: 3, deal_count: 2)
    end
  end
end
