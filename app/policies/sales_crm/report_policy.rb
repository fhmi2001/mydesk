# Custom (MyDesk): everyone may open sales reports (the report services narrow employees to their own deals); only an
# administrator exports them (gap-analysis.md)
class SalesCrm::ReportPolicy < ApplicationPolicy
  def index? = true
  def export? = account_user&.administrator?
  # The reports about the team as a whole (SalesCrm::Reports::Report.admin_only?)
  def team? = account_user&.administrator?
end
