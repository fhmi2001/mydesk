# Custom (MyDesk): everyone may open sales reports (the report services narrow employees to their own deals); only an
# administrator exports them (gap-analysis.md, question 5)
class SalesCrm::ReportPolicy < ApplicationPolicy
  def index? = true
  def export? = account_user&.administrator?
  def settings? = account_user&.administrator?
end
