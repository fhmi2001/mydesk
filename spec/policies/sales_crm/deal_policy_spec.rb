# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SalesCrm::DealPolicy do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:pipeline) { create(:crm_pipeline, account: account) }
  let!(:mine) { create(:crm_deal, account: account, pipeline: pipeline, assignee: agent) }
  let!(:theirs) { create(:crm_deal, account: account, pipeline: pipeline, assignee: other_agent) }
  let!(:unassigned_by_me) { create(:crm_deal, account: account, pipeline: pipeline, creator: agent) }

  def context_for(user)
    { user: user, account: account, account_user: account.account_users.find_by(user: user) }
  end

  def scope_for(user)
    described_class::Scope.new(context_for(user), SalesCrm::Deal).resolve
  end

  it 'an employee sees only the deals they own, never a colleague or an unowned one' do
    expect(scope_for(agent)).to contain_exactly(mine)
    policy = described_class.new(context_for(agent), theirs)
    expect([policy.show?, policy.update?, policy.move?, policy.reopen?]).to all(be(false))
    expect(described_class.new(context_for(agent), unassigned_by_me).show?).to be(false)
  end

  it 'administrators see and change everything' do
    expect(scope_for(admin)).to contain_exactly(mine, theirs, unassigned_by_me)
    expect(described_class.new(context_for(admin), theirs).update?).to be(true)
  end

  it 'only administrators hand a deal to someone else' do
    expect(described_class.new(context_for(agent), mine).reassign?).to be(false)
    expect(described_class.new(context_for(admin), mine).reassign?).to be(true)
  end

  it 'destroy is for administrators or the assignee' do
    expect(described_class.new(context_for(agent), mine).destroy?).to be(true)
    expect(described_class.new(context_for(agent), theirs).destroy?).to be(false)
    expect(described_class.new(context_for(admin), theirs).destroy?).to be(true)
  end

  it 'restore is for administrators only' do
    expect(described_class.new(context_for(agent), mine).restore?).to be(false)
    expect(described_class.new(context_for(admin), mine).restore?).to be(true)
  end

  it 'pipeline writes are for administrators only' do
    expect(SalesCrm::PipelinePolicy.new(context_for(agent), pipeline).update?).to be(false)
    expect(SalesCrm::PipelinePolicy.new(context_for(admin), pipeline).update?).to be(true)
  end

  it 'task destroy is for administrators or the creator' do
    task = create(:crm_task, account: account, creator: agent)
    expect(SalesCrm::TaskPolicy.new(context_for(agent), task).destroy?).to be(true)
    expect(SalesCrm::TaskPolicy.new(context_for(other_agent), task).destroy?).to be(false)
    expect(SalesCrm::TaskPolicy.new(context_for(admin), task).destroy?).to be(true)
  end
end
