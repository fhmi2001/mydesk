# Custom (MyDesk): the deals of the period as CSV, headers in the caller's locale. Cells that a spreadsheet
# would read as a formula are prefixed with an apostrophe (customer names and reasons are free text).
require 'csv'

class SalesCrm::Reports::Export < SalesCrm::Reports::Base
  COLUMNS = %w[title amount currency pipeline stage status contact assignee close_date won_at lost_at lost_reason created_at].freeze
  FORMULA_START = /\A[=+\-@\t\r]/

  def perform
    CSV.generate(headers: true) do |csv|
      csv << COLUMNS.map { |c| I18n.t("sales_crm.export.#{c}") }
      deals.where(created_at: range).includes(:pipeline, :stage, :contact, :assignee).find_each { |deal| csv << row_for(deal) }
    end
  end

  def self.safe_cell(value)
    return value unless value.is_a?(String) && value.match?(FORMULA_START)

    "'#{value}"
  end

  private

  def row_for(deal)
    [deal.title, format('%.2f', deal.amount), deal.currency, deal.pipeline.name, deal.stage.name, deal.status,
     deal.display_contact_name, deal.assignee&.name, deal.close_date, stamp(deal.won_at), stamp(deal.lost_at),
     deal.lost_reason, stamp(deal.created_at)].map { |cell| self.class.safe_cell(cell) }
  end

  def stamp(time)
    time&.in_time_zone(SalesCrm::TimeZone.for(account))&.strftime('%Y-%m-%d %H:%M')
  end
end
