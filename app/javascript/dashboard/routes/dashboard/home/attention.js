// Custom (MyDesk): the home screen's list (docs/superpowers/specs/2026-11-01-home-screen-design.md). The employee's
// "waiting for you now" is single items ranked by urgency; the manager's "needs your attention" is counted lines in a
// fixed order. Raw values only: the page formats them.
export const MAX_ITEMS = 8;
// A conversation waiting this long is late
export const LATE_MINUTES = 60;
// The conversations list's page size (CONVERSATION_RESULTS_PER_PAGE): the home screen reads only the first page
export const PAGE_SIZE = 25;

const RANK = { task_overdue: 0, conversation: 1, task_today: 2, deal: 3 };

// Midday, so a date-only close date sorts by its day whatever the time zone
const dayAt = date => new Date(`${date}T12:00:00`);

export const agentItems = ({
  conversations = [],
  tasks = [],
  deals = [],
  now = new Date(),
}) => {
  const waiting = conversations
    .filter(c => c.waiting_since)
    .map(c => {
      const at = new Date(c.waiting_since * 1000);
      const minutes = Math.floor((now - at) / 60000);
      return {
        kind: 'conversation',
        id: c.id,
        title: c.meta?.sender?.name || '',
        detail: { minutes, message: c.last_non_activity_message?.content },
        at,
        urgent: minutes >= LATE_MINUTES,
      };
    });
  const due = tasks.map(task => ({
    kind: task.overdue ? 'task_overdue' : 'task_today',
    id: task.id,
    title: task.title,
    detail: { dueAt: task.due_at },
    at: new Date(task.due_at),
    urgent: Boolean(task.overdue),
  }));
  const closing = deals.map(deal => ({
    kind: 'deal',
    id: deal.id,
    title: deal.title,
    detail: { closeDate: deal.close_date },
    at: dayAt(deal.close_date),
    urgent: false,
  }));
  return [...due, ...waiting, ...closing]
    .sort((a, b) => RANK[a.kind] - RANK[b.kind] || a.at - b.at)
    .slice(0, MAX_ITEMS);
};

export const managerItems = ({
  unassigned,
  waitingLong,
  leak,
  stale,
  lateTasks,
}) =>
  [
    unassigned?.count && {
      kind: 'unassigned',
      count: unassigned.count,
      data: unassigned,
    },
    waitingLong?.count && {
      kind: 'waiting_long',
      count: waitingLong.count,
      data: waitingLong,
    },
    leak && { kind: 'leak', data: leak },
    stale?.count && { kind: 'stale', count: stale.count, data: stale },
    lateTasks?.count && {
      kind: 'late_tasks',
      count: lateTasks.count,
      data: lateTasks,
    },
  ].filter(Boolean);

// The employee's attainment of this month's target, in percent (the quota report is already their own); null without one
export const agentTargetRate = quota =>
  quota?.totals?.target_cents > 0 ? quota.totals.attainment : null;

// How many of the first page of open conversations (longest wait first) have waited LATE_MINUTES or more. A full page
// that is all late may hide more: `more` says so.
export const lateCount = (conversations, now = new Date()) => {
  const cutoff = now.getTime() / 1000 - LATE_MINUTES * 60;
  const count = conversations.filter(
    c => c.waiting_since && c.waiting_since <= cutoff
  ).length;
  return {
    count,
    more: conversations.length >= PAGE_SIZE && count === conversations.length,
  };
};
