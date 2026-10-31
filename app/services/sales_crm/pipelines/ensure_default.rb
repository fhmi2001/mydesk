# Custom (MyDesk): the account's first pipeline («المبيعات») with the standard six stages, created once
class SalesCrm::Pipelines::EnsureDefault
  DEFAULT_STAGES = [
    ['عميل محتمل', 10, :open, '#94a3b8'],
    ['مؤهل', 25, :open, '#60a5fa'],
    ['تم إرسال العرض', 50, :open, '#a78bfa'],
    ['تفاوض', 75, :open, '#f59e0b'],
    ['مكسوبة', 100, :won, '#22c55e'],
    ['خاسرة', 0, :lost, '#ef4444']
  ].freeze

  def self.call(account)
    existing = account.crm_pipelines.first
    return existing if existing

    ActiveRecord::Base.transaction do
      pipeline = account.crm_pipelines.create!(name: SalesCrm::Pipeline::DEFAULT_NAME, currency: default_currency(account))
      DEFAULT_STAGES.each_with_index do |(name, probability, kind, color), position|
        pipeline.stages.create!(account: account, name: name, probability: probability, kind: kind, color: color, position: position)
      end
      pipeline
    end
  end

  def self.default_currency(account)
    currency = account.crm_default_currency.to_s.upcase
    SalesCrm::Pipeline::CURRENCIES.include?(currency) ? currency : 'SAR'
  end
end
