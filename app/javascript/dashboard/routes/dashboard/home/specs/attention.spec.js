import {
  agentItems,
  managerItems,
  agentTargetRate,
  MAX_ITEMS,
  PAGE_SIZE,
  lateCount,
} from '../attention';

const now = new Date('2026-11-01T09:00:00Z');
const minutesAgo = m => Math.floor(now.getTime() / 1000) - m * 60;
const conversation = (id, waitedMinutes) => ({
  id,
  waiting_since: waitedMinutes == null ? null : minutesAgo(waitedMinutes),
  meta: { sender: { name: `Contact ${id}` } },
});

describe('agentItems', () => {
  it('orders overdue tasks, then conversations by oldest wait, then tasks due today, then deals by nearest close', () => {
    const items = agentItems({
      now,
      conversations: [conversation(2, 8), conversation(1, 25)],
      tasks: [
        {
          id: 10,
          title: 'Call',
          due_at: '2026-11-01T13:00:00Z',
          overdue: false,
        },
        {
          id: 11,
          title: 'Offer',
          due_at: '2026-10-30T09:00:00Z',
          overdue: true,
        },
      ],
      deals: [{ id: 20, title: 'Riyan', close_date: '2026-11-02' }],
    });
    expect(items.map(i => i.kind)).toEqual([
      'task_overdue',
      'conversation',
      'conversation',
      'task_today',
      'deal',
    ]);
    expect(items[1].id).toBe(1);
    expect(items[2].id).toBe(2);
  });

  it('skips conversations that are not waiting', () => {
    const items = agentItems({
      now,
      conversations: [
        { ...conversation(1, 5), waiting_since: null },
        { ...conversation(2, 5), waiting_since: 0 },
      ],
    });
    expect(items).toEqual([]);
  });

  it('caps the list', () => {
    const conversations = Array.from({ length: 12 }, (_, i) =>
      conversation(i + 1, i + 1)
    );
    expect(agentItems({ now, conversations })).toHaveLength(MAX_ITEMS);
    expect(MAX_ITEMS).toBe(8);
  });

  it('marks overdue tasks and conversations waiting an hour or more as urgent', () => {
    const items = agentItems({
      now,
      conversations: [conversation(1, 60), conversation(2, 59)],
      tasks: [
        {
          id: 11,
          title: 'Offer',
          due_at: '2026-10-30T09:00:00Z',
          overdue: true,
        },
        {
          id: 10,
          title: 'Call',
          due_at: '2026-11-01T13:00:00Z',
          overdue: false,
        },
      ],
    });
    const urgent = Object.fromEntries(
      items.map(i => [`${i.kind}${i.id}`, i.urgent])
    );
    expect(urgent).toEqual({
      task_overdue11: true,
      conversation1: true,
      conversation2: false,
      task_today10: false,
    });
  });
});

describe('managerItems', () => {
  it('keeps the fixed order and drops zero counts', () => {
    const lines = managerItems({
      unassigned: { count: 6, oldestAt: null },
      waitingLong: { count: 0 },
      leak: { name: 'عرض السعر', rate: 0.3 },
      stale: { count: 8, amount: 120000 },
      lateTasks: { count: 5, topName: 'سالم', topCount: 3 },
    });
    expect(lines.map(l => l.kind)).toEqual([
      'unassigned',
      'leak',
      'stale',
      'late_tasks',
    ]);
  });

  it('drops sources that are missing', () => {
    const lines = managerItems({
      unassigned: { count: 2, oldestAt: null },
      waitingLong: { count: 1 },
      leak: null,
      stale: null,
      lateTasks: null,
    });
    expect(lines.map(l => l.kind)).toEqual(['unassigned', 'waiting_long']);
  });
});

describe('agentTargetRate', () => {
  it('is unknown without a target', () => {
    expect(agentTargetRate(null)).toBeNull();
    expect(
      agentTargetRate({ totals: { target_cents: 0, attainment: null } })
    ).toBeNull();
  });

  it('is the attainment percent when there is a target', () => {
    expect(
      agentTargetRate({ totals: { target_cents: 10000, attainment: 62 } })
    ).toBe(62);
  });
});

describe('lateCount', () => {
  it('counts the conversations waiting an hour or more', () => {
    expect(
      lateCount(
        [conversation(1, 90), conversation(2, 30), conversation(3, 0)],
        now
      )
    ).toEqual({ count: 1, more: false });
  });

  it('says there may be more when a full page is all late', () => {
    const page = Array.from({ length: PAGE_SIZE }, (_, i) =>
      conversation(i + 1, 120)
    );
    expect(lateCount(page, now)).toEqual({ count: PAGE_SIZE, more: true });
  });
});
