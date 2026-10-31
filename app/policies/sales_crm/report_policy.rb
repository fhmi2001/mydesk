# Custom (MyDesk): everyone may open sales reports; the report services narrow agents to their own numbers
class SalesCrm::ReportPolicy < ApplicationPolicy
  def index? = true
  def export? = true
  def settings? = account_user&.administrator?
end
