// Custom (MyDesk)
import { actions, mutations, state as baseState, types } from '../deals';

vi.mock('dashboard/api/crm', () => ({
  crmDealsAPI: {
    get: vi.fn(),
    move: vi.fn(),
    forecast: vi.fn().mockResolvedValue({ data: {} }),
  },
}));

import { crmDealsAPI } from 'dashboard/api/crm';

const deal = (id, stageId, position) => ({
  id,
  stage_id: stageId,
  position,
  lock_version: 0,
  title: `d${id}`,
});

const freshState = () => {
  const s = JSON.parse(JSON.stringify(baseState));
  mutations[types.SET_BOARD](s, {
    deals: [deal(1, 10, 1), deal(2, 10, 2), deal(3, 20, 1)],
    counts: {},
    per_stage_limit: 100,
  });
  s.filters.pipelineId = 5;
  s.uiFlags.hasFetched = true;
  return s;
};

describe('crm/deals store', () => {
  it('SET_BOARD groups deals by stage in position order', () => {
    const s = freshState();
    expect(s.order[10]).toEqual([1, 2]);
    expect(s.order[20]).toEqual([3]);
  });

  it('move places the card optimistically and keeps the server answer', async () => {
    const s = freshState();
    crmDealsAPI.move.mockResolvedValue({
      data: { ...deal(1, 20, 1), lock_version: 1 },
    });
    const commit = (type, payload) => mutations[type](s, payload);
    const dispatch = vi.fn();
    await actions.move(
      { commit, state: s, dispatch },
      { id: 1, stageId: 20, position: 0 }
    );
    expect(s.order[10]).toEqual([2]);
    expect(s.order[20]).toEqual([1, 3]);
    expect(s.records[1].lock_version).toBe(1);
    expect(crmDealsAPI.move).toHaveBeenCalledWith(1, {
      stage_id: 20,
      position: 1,
      lost_reason: undefined,
      lost_note: undefined,
      lock_version: 0,
    });
  });

  it('move reverts the card when the server refuses', async () => {
    const s = freshState();
    crmDealsAPI.move.mockRejectedValue({
      response: { status: 422, data: { message: 'reason required' } },
    });
    const commit = (type, payload) => mutations[type](s, payload);
    await expect(
      actions.move(
        { commit, state: s, dispatch: vi.fn() },
        { id: 1, stageId: 20, position: 0 }
      )
    ).rejects.toBeTruthy();
    expect(s.order[10]).toEqual([1, 2]);
    expect(s.order[20]).toEqual([3]);
    expect(s.records[1].stage_id).toBe(10);
    expect(s.records[1].position).toBe(1);
  });

  it('UPSERT of a discarded deal removes it from the board', () => {
    const s = freshState();
    mutations[types.UPSERT](s, {
      ...deal(2, 10, 2),
      discarded_at: '2026-10-31T00:00:00Z',
    });
    expect(s.order[10]).toEqual([1]);
    expect(s.records[2]).toBeUndefined();
  });

  it('onRemoteChange ignores other pipelines', () => {
    const s = freshState();
    const dispatch = vi.fn().mockResolvedValue();
    actions.onRemoteChange({ dispatch, state: s }, { pipeline_id: 99 });
    expect(dispatch).not.toHaveBeenCalled();
    actions.onRemoteChange({ dispatch, state: s }, { pipeline_id: 5 });
    expect(dispatch).toHaveBeenCalledWith('fetchBoard');
  });

  it('move without a loaded record goes straight to the server with the given lock version', async () => {
    const s = freshState();
    crmDealsAPI.move.mockResolvedValue({
      data: { ...deal(42, 20, 1), lock_version: 3 },
    });
    const commit = (type, payload) => mutations[type](s, payload);
    const result = await actions.move(
      { commit, state: s, dispatch: vi.fn() },
      { id: 42, stageId: 20, lostReason: 'x', lockVersion: 2 }
    );
    expect(crmDealsAPI.move).toHaveBeenCalledWith(42, {
      stage_id: 20,
      lost_reason: 'x',
      lost_note: undefined,
      lock_version: 2,
    });
    expect(result.lock_version).toBe(3);
    expect(s.records[42]).toBeTruthy();
  });

  it('loadMoreForStage asks for the next page of that stage in board order and appends it', async () => {
    const s = freshState();
    crmDealsAPI.get.mockResolvedValue({ data: { deals: [deal(9, 10, 3)] } });
    const commit = (type, payload) => mutations[type](s, payload);
    const count = await actions.loadMoreForStage({ commit, state: s }, 10);
    expect(crmDealsAPI.get).toHaveBeenCalledWith(
      expect.objectContaining({
        pipeline_id: 5,
        stage_id: 10,
        view: 'table',
        sort: 'position:asc',
        page: 1,
      })
    );
    expect(count).toBe(1);
    expect(s.order[10]).toEqual([1, 2, 9]);
  });

  it('keeps the column counts and totals in step with moves, edits, new and removed deals', () => {
    const s = JSON.parse(JSON.stringify(baseState));
    const d = (id, stageId, cents) => ({
      ...deal(id, stageId, 1),
      amount_cents: cents,
    });
    mutations[types.SET_BOARD](s, {
      deals: [d(1, 10, 1000), d(2, 10, 500)],
      counts: {
        10: { count: 3, total_cents: 1800 },
        20: { count: 0, total_cents: 0 },
      },
    });
    // dragged to stage 20
    mutations[types.PLACE](s, { id: 1, stageId: 20, position: 0 });
    expect(s.counts[10]).toEqual({ count: 2, total_cents: 800 });
    expect(s.counts[20]).toEqual({ count: 1, total_cents: 1000 });
    // the server confirms with a new amount
    mutations[types.UPSERT](s, d(1, 20, 1500));
    expect(s.counts[20]).toEqual({ count: 1, total_cents: 1500 });
    // a new deal, then a deleted one
    mutations[types.UPSERT](s, d(7, 10, 200));
    expect(s.counts[10]).toEqual({ count: 3, total_cents: 1000 });
    mutations[types.REMOVE](s, 2);
    expect(s.counts[10]).toEqual({ count: 2, total_cents: 500 });
    // "show more" brings deals that the counts already include
    mutations[types.UPSERT_LOADED](s, d(8, 10, 300));
    expect(s.counts[10]).toEqual({ count: 2, total_cents: 500 });
  });

  it('moves the weighted total with each deal at its own probability', () => {
    const s = JSON.parse(JSON.stringify(baseState));
    mutations[types.SET_BOARD](s, {
      deals: [{ ...deal(1, 10, 1), amount_cents: 1000, probability: 60 }],
      counts: {
        10: { count: 1, total_cents: 1000, weighted_cents: 600 },
        20: { count: 0, total_cents: 0, weighted_cents: 0 },
      },
    });
    mutations[types.PLACE](s, { id: 1, stageId: 20, position: 0 });
    // the server answers with the new stage's probability (the override is dropped on a move)
    mutations[types.UPSERT](s, {
      ...deal(1, 20, 1),
      amount_cents: 1000,
      probability: 25,
    });
    expect(s.counts[10]).toEqual({
      count: 0,
      total_cents: 0,
      weighted_cents: 0,
    });
    expect(s.counts[20]).toEqual({
      count: 1,
      total_cents: 1000,
      weighted_cents: 250,
    });
  });

  it('keeps counts without money (an agent on the team board) without money', () => {
    const s = JSON.parse(JSON.stringify(baseState));
    mutations[types.SET_BOARD](s, {
      deals: [{ ...deal(1, 10, 1), amount_cents: 1000 }],
      counts: { 10: { count: 1 }, 20: { count: 0 } },
    });
    mutations[types.PLACE](s, { id: 1, stageId: 20, position: 0 });
    expect(s.counts[10]).toEqual({ count: 0 });
    expect(s.counts[20]).toEqual({ count: 1 });
  });
});
