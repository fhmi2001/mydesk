# Custom (MyDesk): the task tabs. `scope` is the authorized relation (TaskPolicy::Scope).
class SalesCrm::Tasks::List < SalesCrm::BaseService
  SCOPES = %w[mine today overdue upcoming done all].freeze
  PER_PAGE = 50

  # filters: kind (one of SCOPES), contact_id, deal_id, page, now.
  # With deal_id or contact_id the list is that record's whole history (open first, then done), whatever the kind.
  def perform(scope, **filters)
    now = filters[:now] || Time.current
    relation = scope.includes(:assignee, :contact, :deal, :conversation)
    relation = if filters[:deal_id].present? || filters[:contact_id].present?
                 for_record(relation, filters)
               else
                 apply_kind(relation, kind_for(filters[:kind]), now).order(Arel.sql('due_at ASC NULLS LAST, id DESC'))
               end
    relation.page(filters[:page].to_i.clamp(1, 10_000)).per(PER_PAGE)
  end

  def overdue_count(scope, now: Time.current)
    scope.open.where(assignee_id: user.id).where(due_at: ...now).count
  end

  private

  def for_record(relation, filters)
    relation = relation.where(deal_id: filters[:deal_id]) if filters[:deal_id].present?
    relation = relation.where(contact_id: filters[:contact_id]) if filters[:contact_id].present?
    relation.order(Arel.sql('status ASC, due_at ASC NULLS LAST, id DESC'))
  end

  def kind_for(value)
    kind = value.to_s
    kind = 'mine' if kind == 'all' && !admin?
    SCOPES.include?(kind) ? kind : 'mine'
  end

  def admin?
    SalesCrm::Visibility.admin?(account, user)
  end

  def apply_kind(relation, kind, now)
    today = SalesCrm::TimeZone.today_range(account, now)
    case kind
    when 'mine' then relation.open.where(assignee_id: user.id)
    when 'today' then relation.open.where(due_at: today)
    when 'overdue' then relation.open.where(due_at: ...now)
    when 'upcoming' then relation.open.where(due_at: (today.end + 1.second)..)
    when 'done' then relation.done.reorder(done_at: :desc, id: :desc)
    else relation.open
    end
  end
end
