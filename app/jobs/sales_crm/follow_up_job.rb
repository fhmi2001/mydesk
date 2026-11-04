# Custom (MyDesk): the follow-up when a customer goes quiet (CONVERSATION_SALES_PLAN.md), hourly. An open deal in
# a stage with silence_followup, whose employee last wrote in its active conversation over the account's silent days
# ago and whose customer has not written since (in any conversation), gets a follow-up task for its owner and an empty
# follow-up suggestion; the draft is written only when the employee asks for it. Once per silence: nothing again until
# the employee writes to the customer. Nothing ever reaches the customer from here.
class SalesCrm::FollowUpJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Account.where(id: SalesCrm::Stage.where(silence_followup: true).select(:account_id)).find_each do |account|
      next unless account.feature_enabled?('sales_crm')

      I18n.with_locale(account.locale.presence || I18n.default_locale) { follow_up_account(account) }
    end
  end

  private

  def follow_up_account(account)
    candidates(account).find_each do |deal|
      follow_up(deal) if silent?(deal)
    end
  end

  def candidates(account)
    account.crm_deals.kept.open.where(stage_id: account.crm_stages.where(silence_followup: true).select(:id))
           .where.not(active_conversation_id: nil).where(last_message_at: ..account.crm_followup_days_value.days.ago)
  end

  # The customer has not written since, and this silence has not been followed up yet
  def silent?(deal)
    return false if deal.tasks.from_follow_up.where(created_at: deal.last_message_at..).or(deal.tasks.open.from_follow_up).exists?
    return true if deal.contact_id.blank?

    !Message.incoming.where(conversation_id: deal.account.conversations.where(contact_id: deal.contact_id).select(:id))
            .exists?(created_at: deal.last_message_at..)
  end

  def follow_up(deal)
    ActiveRecord::Base.transaction do
      SalesCrm::Tasks::Create.new(account: deal.account).record!(
        title: I18n.t('sales_crm.follow_up.task_title', title: deal.title), due_at: Time.current, origin: :follow_up,
        **SalesCrm::StageEntry.task_links(deal)
      )
      SalesCrm::Suggestions::Create.for_deal(deal, :follow_up)
    end
  end
end
