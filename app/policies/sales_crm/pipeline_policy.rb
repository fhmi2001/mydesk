# Custom (MyDesk): everyone reads pipelines; only administrators change them
class SalesCrm::PipelinePolicy < ApplicationPolicy
  def index? = true
  def show? = true
  def create? = account_user&.administrator?
  def update? = create?
  def destroy? = create?

  class Scope < Scope
    def resolve
      account.crm_pipelines
    end
  end
end
