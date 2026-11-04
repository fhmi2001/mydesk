# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SalesCrm::PurgeDismissedSuggestionsJob do
  let(:account) { create(:account) }

  def suggestion(status, decided_at)
    SalesCrm::Suggestion.create!(account: account, conversation: create(:conversation, account: account), kind: :new_deal,
                                 status: status, decided_at: decided_at)
  end

  it 'deletes the suggestions dismissed more than 30 days ago and keeps the rest' do
    old_dismissed = suggestion(:dismissed, 31.days.ago)
    recent_dismissed = suggestion(:dismissed, 2.days.ago)
    old_accepted = suggestion(:accepted, 60.days.ago)

    described_class.perform_now

    expect(SalesCrm::Suggestion.pluck(:id)).to contain_exactly(recent_dismissed.id, old_accepted.id)
    expect(SalesCrm::Suggestion.exists?(old_dismissed.id)).to be(false)
  end
end
