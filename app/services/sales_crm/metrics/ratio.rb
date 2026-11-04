# Custom (MyDesk): the division every metric shares. Dividing by nothing gives nil, never zero, and the screens show
# it as «—» (CRM_REPORTS_PLAN.md): a win rate with no closed deal is unknown, not 0%.
module SalesCrm::Metrics::Ratio
  module_function

  # A percentage with one decimal
  def percent(part, whole)
    whole.to_f.zero? ? nil : (part.to_f * 100 / whole).round(1)
  end

  # A plain ratio with one decimal (e.g. a coverage of 2.5 times)
  def times(part, whole)
    whole.to_f.zero? ? nil : (part.to_f / whole).round(1)
  end

  # A whole-number average (cents)
  def average_cents(total, count)
    count.to_i.zero? ? nil : total.to_i / count.to_i
  end
end
