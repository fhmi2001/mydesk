# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SalesCrm::Suggestion do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:deal) { create(:crm_deal, account: account) }

  def suggest(kind, **attrs)
    described_class.create!(account: account, conversation: conversation, kind: kind, **attrs)
  end

  describe 'one pending suggestion' do
    it 'per conversation for a new deal' do
      suggest(:new_deal)
      expect { suggest(:new_deal) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows a new one once the last was decided' do
      suggest(:new_deal).update!(status: :dismissed)
      expect { suggest(:new_deal) }.not_to raise_error
    end

    it 'per deal for a follow-up, so two deals in one conversation each get theirs' do
      other = create(:crm_deal, account: account)
      suggest(:follow_up, deal: deal)
      expect { suggest(:follow_up, deal: other) }.not_to raise_error
      expect { suggest(:follow_up, deal: deal) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  it 'needs a deal for the deal kinds' do
    expect(described_class.new(account: account, conversation: conversation, kind: :won_message)).not_to be_valid
    expect(described_class.new(account: account, conversation: conversation, kind: :new_deal)).to be_valid
  end

  describe 'reaching the open conversation panel live' do
    let!(:admin) { create(:user, account: account, role: :administrator) }
    let(:handler) { create(:user, account: account, role: :agent) }
    let(:owner) { create(:user, account: account, role: :agent) }

    it "tells the conversation's assignee and the administrators about a new deal suggestion" do
      conversation.update!(assignee: handler)
      expect { suggest(:new_deal) }.to have_enqueued_job(ActionCableBroadcastJob).with(
        contain_exactly(admin.pubsub_token, handler.pubsub_token), 'crm.suggestion_created',
        hash_including(kind: 'new_deal', conversation_display_id: conversation.display_id)
      )
    end

    it "tells the deal's owner, not the conversation's assignee, about a follow-up" do
      conversation.update!(assignee: handler)
      deal.update!(assignee: owner)
      expect { suggest(:follow_up, deal: deal) }.to have_enqueued_job(ActionCableBroadcastJob).with(
        contain_exactly(admin.pubsub_token, owner.pubsub_token), 'crm.suggestion_created', anything
      )
    end
  end

  describe '#decide!' do
    let(:user) { create(:user, account: account) }

    it 'records who decided and when' do
      suggestion = suggest(:new_deal)
      freeze_time do
        suggestion.decide!(:accepted, user)
        expect(suggestion.reload).to have_attributes(status: 'accepted', decided_by_id: user.id, decided_at: Time.current)
      end
    end

    it 'refuses a suggestion that was already decided' do
      suggestion = suggest(:new_deal)
      suggestion.decide!(:dismissed, user)
      expect { suggestion.decide!(:accepted, user) }.to raise_error(SalesCrm::Suggestion::AlreadyDecided)
    end
  end
end
