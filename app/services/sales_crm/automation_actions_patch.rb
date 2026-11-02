# Custom (MyDesk): the Sales actions of automation rules (CONVERSATION_SALES_PLAN.md, idea ج1), prepended into
# AutomationRules::ActionService from config/initializers/sales_crm.rb so Chatwoot's file keeps only the action names.
# Each acts on the rule's conversation and does nothing for an account without the Sales section. They act as the
# system (no user), so a deal's last activity does not move.
#   suggest_crm_deal  [{ title }]               a pending «صفقة جديدة» suggestion (a deal needs an amount and a date)
#   create_crm_task   [{ title, kind, hours }]  a task for the conversation's assignee, else an administrator
#   move_crm_deal     [{ stage_id }]            the deal followed in the conversation to that stage, never to lost
module SalesCrm::AutomationActionsPatch
  private

  def suggest_crm_deal(params)
    return unless crm_automation?

    title = [crm_param(params, :title), @conversation.contact&.name].compact_blank.join(' — ')
    # Once per conversation: a rule on «تم تحديث المحادثة» runs again on every later update, and a dismissed
    # suggestion or a deal already followed here means the employee has dealt with it
    return if @account.crm_suggestions.new_deal.exists?(conversation_id: @conversation.id) || crm_followed_deal

    @account.crm_suggestions.create!(kind: :new_deal, origin: :automation, conversation: @conversation,
                                     contact_id: @conversation.contact_id, content: { title: title })
  end

  def create_crm_task(params)
    return unless crm_automation?

    deal = crm_followed_deal
    task = @account.crm_tasks.create!(
      title: crm_param(params, :title).to_s.strip.presence || @rule.name, kind: crm_task_kind(params),
      due_at: crm_param(params, :hours).to_i.clamp(0, 24 * 365).hours.from_now, origin: :automation,
      assignee_id: @conversation.assignee_id || @account.account_users.administrator.order(:id).pick(:user_id),
      conversation: @conversation, contact_id: @conversation.contact_id, deal: deal
    )
    SalesCrm::ActivityLog.record(deal: deal, kind: 'task_added', user: nil, data: { task_id: task.id, title: task.title }) if deal
  end

  def move_crm_deal(params)
    return unless crm_automation?

    deal = crm_followed_deal
    stage = crm_target_stage(deal, params)
    SalesCrm::Deals::Move.new(account: @account, user: nil).perform(deal, stage_id: stage.id) if stage
  end

  # A stage of the deal's pipeline other than its own, and never the lost one (it needs a reason)
  def crm_target_stage(deal, params)
    stage = deal&.pipeline&.stages&.find_by(id: crm_param(params, :stage_id))
    stage if stage && !stage.lost? && stage.id != deal.stage_id
  end

  def crm_automation? = @account.feature_enabled?('sales_crm')

  def crm_followed_deal
    @account.crm_deals.kept.open.where(active_conversation_id: @conversation.id).order(updated_at: :desc).first
  end

  def crm_param(params, key)
    config = Array.wrap(params).first
    config.respond_to?(:with_indifferent_access) ? config.with_indifferent_access[key] : nil
  end

  def crm_task_kind(params)
    kind = crm_param(params, :kind).to_s
    SalesCrm::Task.kinds.key?(kind) ? kind : 'task'
  end
end
