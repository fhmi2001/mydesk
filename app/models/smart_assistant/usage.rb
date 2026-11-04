# Custom (MyDesk): the tokens and cost of one smart assistant call to OpenAI, for the usage tab of the account
# == Schema Information
#
# Table name: smart_assistant_usages
#
#  id            :bigint           not null, primary key
#  cached_tokens :integer          default(0), not null
#  cost          :decimal(14, 8)
#  input_tokens  :integer          default(0), not null
#  kind          :integer          not null
#  model         :string           not null
#  output_tokens :integer          default(0), not null
#  created_at    :datetime         not null
#  account_id    :bigint           not null
#
# Indexes
#
#  index_smart_assistant_usages_on_account_id_and_created_at  (account_id,created_at)
#
class SmartAssistant::Usage < ApplicationRecord
  TOTALS = %i[input_tokens output_tokens cached_tokens cost].freeze

  # reply: answering a customer, test: the settings test chat, knowledge: reading and embedding sources;
  # crm_*: the Sales section's conversation summary, follow-up draft and won / lost message draft
  enum kind: { reply: 0, test: 1, knowledge: 2, crm_summary: 3, crm_followup: 4, crm_message: 5 }
  CRM_KINDS = %w[crm_summary crm_followup crm_message].freeze

  belongs_to :account

  scope :in_month, ->(time) { where(created_at: time.all_month) }

  # The Sales calls count against their own monthly limit, never the reply quota (which counts the bot's messages)
  def self.crm_calls_this_month(account)
    where(account: account, kind: CRM_KINDS).in_month(Time.current).count
  end

  def self.crm_limit_reached?(account)
    crm_calls_this_month(account) >= SmartAssistant::Config.crm_monthly_limit
  end

  # { 'reply' => { input_tokens:, output_tokens:, cached_tokens:, cost:, calls: }, ... } over the given rows
  def self.totals_by_kind
    totals_grouped_by(group(:kind))
  end

  # [{ month: '2026-10-01', input_tokens:, output_tokens:, cached_tokens:, cost:, calls: }, ...] oldest first
  def self.totals_by_month
    totals_grouped_by(group_by_month(:created_at)).map { |month, totals| totals.merge(month: month.to_date.iso8601) }
  end

  def self.totals_grouped_by(grouped)
    sums = TOTALS.index_with { |column| grouped.sum(column) }
    grouped.count.to_h do |key, calls|
      [key, TOTALS.index_with { |column| sums[column][key] }.merge(calls: calls)]
    end
  end
  private_class_method :totals_grouped_by
end
