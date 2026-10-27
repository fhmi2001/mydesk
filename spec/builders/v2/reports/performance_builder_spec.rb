require 'rails_helper'

describe V2::Reports::PerformanceBuilder do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:since) { 7.days.ago.beginning_of_day }
  let(:params) { { since: since.to_i.to_s, until: Time.current.to_i.to_s } }

  def event(name, value, at: 1.day.ago)
    conversation = create(:conversation, account: account, inbox: inbox, created_at: at)
    create(:reporting_event, account: account, inbox: inbox, conversation: conversation, name: name,
                             value: value, value_in_business_hours: value / 2, created_at: at)
  end

  it 'reports medians and the 90th percentile rather than averages' do
    [60, 120, 180, 240, 3600].each { |seconds| event('first_response', seconds) }

    stats = described_class.new(account: account, params: params).build[:current][:first_response]

    expect(stats).to include(median: 180, count: 5)
    expect(stats[:p90]).to be > 240
  end

  it 'compares with the previous period of the same length' do
    event('conversation_resolved', 100)
    event('conversation_resolved', 300, at: since - 2.days)

    result = described_class.new(account: account, params: params).build

    expect(result[:current][:resolved]).to eq(1)
    expect(result[:previous][:resolved]).to eq(1)
    expect(result[:previous][:resolution][:median]).to eq(300)
  end

  it 'uses business-hours values when asked' do
    event('first_response', 200)

    stats = described_class.new(account: account, params: params.merge(business_hours: 'true')).build

    expect(stats[:current][:first_response][:median]).to eq(100)
  end

  it 'breaks conversations down by channel and counts the unanswered ones' do
    event('first_response', 90)
    create(:conversation, account: account, inbox: inbox, status: :open, first_reply_created_at: nil)

    result = described_class.new(account: account, params: params).build

    expect(result[:channels].first).to include(channel_type: inbox.channel_type, first_response_median: 90)
    expect(result[:unanswered_now]).to be >= 1
  end
end
