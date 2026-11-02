// Custom (MyDesk)
import { actions, mutations, state as baseState } from '../tasks';

vi.mock('dashboard/api/crm', () => ({
  crmTasksAPI: { complete: vi.fn(), get: vi.fn() },
}));

import { crmTasksAPI } from 'dashboard/api/crm';

describe('crm/tasks store', () => {
  it('complete removes the task from an open scope and refreshes the status badge', async () => {
    const s = JSON.parse(JSON.stringify(baseState));
    s.scope = 'mine';
    s.records = [
      { id: 1, status: 'open', title: 'a' },
      { id: 2, status: 'open', title: 'b' },
    ];
    crmTasksAPI.complete.mockResolvedValue({
      data: { id: 1, status: 'done', title: 'a' },
    });
    const commit = (type, payload) => mutations[type](s, payload);
    const dispatch = vi.fn();
    await actions.complete({ commit, dispatch }, 1);
    expect(s.records.map(t => t.id)).toEqual([2]);
    expect(dispatch).toHaveBeenCalledWith('crm/status/fetch', null, {
      root: true,
    });
  });

  it('fetch stores the tasks and pushes the overdue count to the status module', async () => {
    const s = JSON.parse(JSON.stringify(baseState));
    crmTasksAPI.get.mockResolvedValue({
      data: { tasks: [{ id: 3, status: 'open' }], total: 1, overdue_count: 4 },
    });
    const commit = (type, payload) => mutations[type](s, payload);
    const dispatch = vi.fn();
    await actions.fetch({ commit, dispatch }, { scope: 'overdue' });
    expect(s.scope).toBe('overdue');
    expect(s.records).toEqual([{ id: 3, status: 'open' }]);
    expect(dispatch).toHaveBeenCalledWith('crm/status/setOverdueCount', 4, {
      root: true,
    });
    expect(s.uiFlags.hasFetched).toBe(true);
  });

  it('loadMore asks for the next page of the current tab and appends it without duplicates', async () => {
    const s = JSON.parse(JSON.stringify(baseState));
    s.scope = 'all';
    s.total = 52;
    s.records = Array.from({ length: 50 }, (_, i) => ({
      id: i + 1,
      status: 'open',
    }));
    crmTasksAPI.get.mockResolvedValue({
      data: {
        tasks: [
          { id: 50, status: 'open' },
          { id: 51, status: 'open' },
          { id: 52, status: 'open' },
        ],
        total: 52,
      },
    });
    const commit = (type, payload) => mutations[type](s, payload);
    await actions.loadMore({ commit, state: s });
    expect(crmTasksAPI.get).toHaveBeenLastCalledWith({ scope: 'all', page: 2 });
    expect(s.records).toHaveLength(52);
    expect(s.uiFlags.isLoadingMore).toBe(false);
  });

  it('keeps the total in step when a task leaves or joins the tab', () => {
    const s = JSON.parse(JSON.stringify(baseState));
    s.scope = 'mine';
    s.total = 60;
    s.records = [{ id: 1, status: 'open' }];
    mutations['crm/tasks/UPSERT'](s, { id: 1, status: 'done' });
    expect(s.total).toBe(59);
    mutations['crm/tasks/UPSERT'](s, { id: 2, status: 'open' });
    expect(s.total).toBe(60);
    mutations['crm/tasks/REMOVE'](s, 2);
    expect(s.total).toBe(59);
  });
});
