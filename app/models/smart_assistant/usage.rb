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

  # reply: answering a customer, test: the settings test chat, knowledge: reading and embedding sources
  enum kind: { reply: 0, test: 1, knowledge: 2 }

  belongs_to :account

  scope :in_month, ->(time) { where(created_at: time.all_month) }

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
