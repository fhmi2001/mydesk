# Custom (MyDesk): what a deal entering a stage sets off (CONVERSATION_SALES_PLAN.md, phase 3). A stage with a task
# rule (followup_task_days / followup_task_title) gives the deal's owner that task, unless the deal already has an open
# task from a stage rule. Called by SalesCrm::Deals::Create and ::Move inside their transaction.
module SalesCrm::StageEntry
  module_function

  def call(deal, stage)
    open_stage_task(deal, stage)
    suggest_closing_message(deal, stage)
  end

  # The owner, customer and conversation the deal's own task belongs to
  def task_links(deal)
    { deal: deal, assignee_id: deal.assignee_id, contact_id: deal.contact_id, conversation_id: deal.active_conversation_id }
  end

  # Won: a thank-you; lost: a short question about why. Empty suggestions in the deal's conversation; the draft is
  # written when the employee asks, and only they send it (idea ج2)
  def suggest_closing_message(deal, stage)
    kind = { 'won' => :won_message, 'lost' => :lost_question }[stage.kind]
    account = deal.account
    return unless kind && deal.active_conversation_id && account.feature_enabled?('sales_crm') && account.crm_won_lost_messages_value
    return if account.crm_suggestions.pending.exists?(deal_id: deal.id, kind: kind)

    account.crm_suggestions.create!(kind: kind, origin: :schedule, deal: deal, conversation_id: deal.active_conversation_id,
                                    contact_id: deal.contact_id)
  end

  def open_stage_task(deal, stage)
    return unless stage.open? && stage.followup_task_days.present?
    return if deal.tasks.open.from_stage_rule.exists?

    task = deal.account.crm_tasks.create!(title: stage.followup_task_title, due_at: stage.followup_task_days.days.from_now,
                                          origin: :stage_rule, **task_links(deal))
    SalesCrm::ActivityLog.record(deal: deal, kind: 'task_added', user: nil, data: { task_id: task.id, title: task.title })
    SalesCrm::Broadcast.call(deal.account, 'crm.task_created', { id: task.id, assignee_id: task.assignee_id, deal_id: deal.id },
                             to: task.assignee_id)
  end
end
