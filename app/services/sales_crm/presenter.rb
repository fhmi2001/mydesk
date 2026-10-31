# Custom (MyDesk): the JSON shapes the Sales CRM API returns
module SalesCrm::Presenter
  module_function

  def pipeline(pipeline, deals_count: nil)
    { id: pipeline.id, name: pipeline.name, currency: pipeline.currency, position: pipeline.position,
      currency_locked: pipeline.currency_locked?, deals_count: deals_count,
      stages: pipeline.stages.map { |s| stage(s) } }
  end

  def stage(stage)
    { id: stage.id, name: stage.name, probability: stage.probability, kind: stage.kind, position: stage.position, color: stage.color }
  end

  def deal(deal)
    deal_core(deal).merge(deal_people(deal)).merge(deal_outcome(deal))
  end

  def deal_core(deal)
    { id: deal.id, title: deal.title, amount: format('%.2f', deal.amount), amount_cents: deal.amount_cents, currency: deal.currency,
      pipeline_id: deal.pipeline_id, stage_id: deal.stage_id, status: deal.status, priority: deal.priority, position: deal.position,
      description: deal.description, source: deal.source, conversation_id: deal.conversation_id,
      conversation_display_id: deal.conversation&.display_id, lock_version: deal.lock_version,
      created_at: deal.created_at, updated_at: deal.updated_at }
  end

  def deal_people(deal)
    { contact: contact(deal.contact), contact_name: deal.display_contact_name, assignee: user(deal.assignee), creator_id: deal.creator_id }
  end

  def deal_outcome(deal)
    { close_date: deal.close_date, lost_reason: deal.lost_reason, lost_note: deal.lost_note, won_at: deal.won_at, lost_at: deal.lost_at,
      discarded_at: deal.discarded_at }
  end

  def task(task, now: Time.current)
    {
      id: task.id, title: task.title, description: task.description, due_at: task.due_at, status: task.status, done_at: task.done_at,
      assignee: user(task.assignee), creator_id: task.creator_id, contact: contact(task.contact),
      deal: task.deal ? { id: task.deal.id, title: task.deal.title, status: task.deal.status } : nil,
      conversation_id: task.conversation_id, conversation_display_id: task.conversation&.display_id,
      overdue: task.overdue?(now), reminded_at: task.reminded_at,
      created_at: task.created_at, updated_at: task.updated_at
    }
  end

  def note(note)
    { id: note.id, content: note.content, user: user(note.user), created_at: note.created_at }
  end

  def activity(activity)
    { id: activity.id, kind: activity.kind, data: activity.data, user: user(activity.user), created_at: activity.created_at }
  end

  def forecast(result)
    result.to_h
  end

  def contact(contact)
    return nil unless contact

    { id: contact.id, name: contact.name, phone_number: contact.phone_number, email: contact.email, thumbnail: contact.avatar_url }
  end

  def user(user)
    return nil unless user

    { id: user.id, name: user.name, available_name: user.available_name, avatar_url: user.avatar_url }
  end
end
