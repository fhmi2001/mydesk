// Custom (MyDesk): the account's pipelines, as the deals board and Sales settings keep them
import { crmPipelinesAPI } from 'dashboard/api/crm';
import { actions, getters, mutations, types } from '../pipelines';

vi.mock('dashboard/api/crm', () => ({
  crmPipelinesAPI: {
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
  },
}));

const freshState = () => ({
  records: [],
  uiFlags: { isFetching: false, hasFetched: false, isSaving: false },
});

describe('crm/pipelines', () => {
  let commit;

  beforeEach(() => {
    vi.clearAllMocks();
    commit = vi.fn();
  });

  it('fetches the pipelines and marks them fetched even when the request fails', async () => {
    crmPipelinesAPI.get.mockResolvedValue({ data: [{ id: 1, name: 'Sales' }] });
    await actions.fetch({ commit });
    expect(commit).toHaveBeenCalledWith(types.SET, [{ id: 1, name: 'Sales' }]);

    commit.mockClear();
    crmPipelinesAPI.get.mockRejectedValue(new Error('offline'));
    await expect(actions.fetch({ commit })).rejects.toThrow('offline');
    expect(commit).toHaveBeenLastCalledWith(types.SET_FLAGS, {
      isFetching: false,
      hasFetched: true,
    });
  });

  it('sends an update without the id in its body and stores the answer', async () => {
    crmPipelinesAPI.update.mockResolvedValue({ data: { id: 2, name: 'B2B' } });
    await actions.update({ commit }, { id: 2, name: 'B2B' });
    expect(crmPipelinesAPI.update).toHaveBeenCalledWith(2, { name: 'B2B' });
    expect(commit).toHaveBeenCalledWith(types.UPSERT, { id: 2, name: 'B2B' });
  });

  it('adds, replaces and removes pipelines in place', () => {
    const state = freshState();
    mutations[types.UPSERT](state, { id: 1, name: 'Sales' });
    mutations[types.UPSERT](state, { id: 2, name: 'B2B' });
    mutations[types.UPSERT](state, { id: 1, name: 'Retail' });
    expect(state.records.map(p => p.name)).toEqual(['Retail', 'B2B']);

    mutations[types.REMOVE](state, '1');
    expect(getters.all(state)).toEqual([{ id: 2, name: 'B2B' }]);
    expect(getters.byId(state)('2')).toEqual({ id: 2, name: 'B2B' });
    expect(getters.first(state)).toEqual({ id: 2, name: 'B2B' });
  });
});
