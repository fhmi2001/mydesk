// Custom (MyDesk)
import { actions, mutations, state as baseState, types } from '../deals';

vi.mock('dashboard/api/crm', () => ({
  crmDealsAPI: {
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
      lock_version: 2,
    });
    expect(result.lock_version).toBe(3);
    expect(s.records[42]).toBeTruthy();
  });
});
