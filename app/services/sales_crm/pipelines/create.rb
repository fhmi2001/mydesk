# Custom (MyDesk): a new pipeline with its stages (the standard six when none are given)
class SalesCrm::Pipelines::Create < SalesCrm::BaseService
  def perform(name:, currency: nil, stages: nil)
    ActiveRecord::Base.transaction do
      pipeline = account.crm_pipelines.create!(name: name.to_s.strip, currency: currency_for(currency),
                                               position: (account.crm_pipelines.maximum(:position) || 0) + 1)
      stage_rows(stages).each_with_index { |row, index| create_stage(pipeline, row, index) }
      pipeline.stages.reload
      pipeline
    end
  end

  private

  def currency_for(currency)
    (currency.presence || SalesCrm::Pipelines::EnsureDefault.default_currency(account)).upcase
  end

  def stage_rows(stages)
    return stages.map { |row| row.to_h.symbolize_keys } if stages.present?

    SalesCrm::Pipelines::EnsureDefault::DEFAULT_STAGES.map { |n, p, k, c| { name: n, probability: p, kind: k, color: c } }
  end

  def create_stage(pipeline, row, index)
    pipeline.stages.create!(account: account, name: row[:name], probability: row[:probability], kind: row[:kind],
                            color: row[:color].presence || SalesCrm::Stage::DEFAULT_COLORS[row[:kind].to_s], position: index)
  end
end
