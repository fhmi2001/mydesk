# Custom (MyDesk): المؤشر 2, نسبة الإنجاز: value won in the period ÷ the period's target (SalesCrm::Metrics::Target).
# Without a target the attainment is unknown (nil), not 0%.
module SalesCrm::Metrics::QuotaAttainment
  module_function

  def call(won_cents:, target_cents:)
    SalesCrm::Metrics::Ratio.percent(won_cents, target_cents)
  end
end
