# Custom (MyDesk)
require 'rails_helper'

# Who sees which suggestion (docs/mydesk/CONVERSATION_SALES_PLAN.md): a new deal or a note goes to the
# employee the conversation is assigned to; a deal's follow-up, won and lost messages go to the deal's owner.
# Administrators see them all.
RSpec.describe SalesCrm::Visibility, '.suggestions' do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:handler) { create(:user, account: account, role: :agent) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: handler) }
  let(:deal) { create(:crm_deal, account: account, assignee: owner) }
  let!(:new_deal) { SalesCrm::Suggestion.create!(account: account, conversation: conversation, kind: :new_deal) }
  let!(:follow_up) { SalesCrm::Suggestion.create!(account: account, conversation: conversation, deal: deal, kind: :follow_up) }

  it 'shows the conversation suggestion to the employee handling the conversation only' do
    expect(described_class.suggestions(account, handler)).to contain_exactly(new_deal)
  end

  it "shows a deal's suggestion to its owner only, even when someone else handles the conversation" do
    expect(described_class.suggestions(account, owner)).to contain_exactly(follow_up)
  end

  it 'shows an administrator everything' do
    expect(described_class.suggestions(account, admin)).to contain_exactly(new_deal, follow_up)
  end
end
