# Custom (MyDesk): lost reasons in the period, grouped after normalization (so spelling variants merge),
# shown with the first spelling seen, most frequent first
class SalesCrm::Reports::LostReasons < SalesCrm::Reports::Base
  def perform
    groups = {}
    deals.lost.where(lost_at: range).order(:lost_at).pluck(:lost_reason, :amount_cents).each do |reason, cents|
      key = SalesCrm::Normalize.loose(reason).presence || '-'
      group = groups[key] ||= { reason: reason.presence || '-', count: 0, total_cents: 0 }
      group[:count] += 1
      group[:total_cents] += cents
    end
    groups.values.sort_by { |g| [-g[:count], -g[:total_cents]] }
  end
end
