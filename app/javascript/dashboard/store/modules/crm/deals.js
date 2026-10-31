// Custom (MyDesk): the deals board. Moves are optimistic: the card jumps at once and snaps back if the
// server refuses (no lost reason, stale version, outage).
import { crmDealsAPI } from 'dashboard/api/crm';

export const types = {
  SET_BOARD: 'crm/deals/SET_BOARD',
  SET_FORECAST: 'crm/deals/SET_FORECAST',
  UPSERT: 'crm/deals/UPSERT',
  REMOVE: 'crm/deals/REMOVE',
  PLACE: 'crm/deals/PLACE',
  SET_FILTERS: 'crm/deals/SET_FILTERS',
  SET_FLAGS: 'crm/deals/SET_FLAGS',
};

export const state = {
  records: {}, // id -> deal
  order: {}, // stageId -> [dealId] in position order
  counts: {}, // stageId -> { count, total_cents }
  forecast: null,
  perStageLimit: 100,
  filters: { pipelineId: null, assigneeId: '', status: '', q: '' },
  uiFlags: {
    isFetching: false,
    hasFetched: false,
    isSaving: false,
    isUnavailable: false,
  },
};

const sortIds = (records, ids) =>
  [...ids].sort(
    (a, b) => (records[a]?.position ?? 0) - (records[b]?.position ?? 0) || b - a
  );

export const getters = {
  byId: _state => id => _state.records[id],
  dealsForStage: _state => stageId =>
    (_state.order[stageId] || []).map(id => _state.records[id]).filter(Boolean),
  counts: _state => _state.counts,
  forecast: _state => _state.forecast,
  filters: _state => _state.filters,
  perStageLimit: _state => _state.perStageLimit,
  getUIFlags: _state => _state.uiFlags,
  allLoaded: _state => Object.values(_state.records),
};

const unavailable = error => error?.response?.status >= 500 || !error?.response;

export const actions = {
  setFilters({ commit }, filters) {
    commit(types.SET_FILTERS, filters);
  },

  async fetchBoard({ commit, state: _state }) {
    if (!_state.filters.pipelineId) return;
    commit(types.SET_FLAGS, { isFetching: true });
    try {
      const params = {
        pipeline_id: _state.filters.pipelineId,
        assignee_id: _state.filters.assigneeId || undefined,
        status: _state.filters.status || undefined,
        q: _state.filters.q || undefined,
        view: 'board',
      };
      const [{ data }, forecast] = await Promise.all([
        crmDealsAPI.get(params),
        crmDealsAPI.forecast({
          pipeline_id: params.pipeline_id,
          assignee_id: params.assignee_id,
        }),
      ]);
      commit(types.SET_BOARD, data);
      commit(types.SET_FORECAST, forecast.data);
      commit(types.SET_FLAGS, {
        isFetching: false,
        hasFetched: true,
        isUnavailable: false,
      });
    } catch (error) {
      commit(types.SET_FLAGS, {
        isFetching: false,
        hasFetched: true,
        isUnavailable: unavailable(error),
      });
      throw error;
    }
  },

  async fetchOne({ commit }, id) {
    const { data } = await crmDealsAPI.show(id);
    commit(types.UPSERT, data);
    return data;
  },

  async create({ commit, dispatch }, deal) {
    commit(types.SET_FLAGS, { isSaving: true });
    try {
      const { data } = await crmDealsAPI.create(deal);
      commit(types.UPSERT, data);
      dispatch('refreshForecast');
      return data;
    } finally {
      commit(types.SET_FLAGS, { isSaving: false });
    }
  },

  async update({ commit, dispatch }, { id, ...deal }) {
    commit(types.SET_FLAGS, { isSaving: true });
    try {
      const { data } = await crmDealsAPI.update(id, deal);
      commit(types.UPSERT, data);
      dispatch('refreshForecast');
      return data;
    } finally {
      commit(types.SET_FLAGS, { isSaving: false });
    }
  },

  // Optimistic: place the card, call the server, snap back on failure
  async move(
    { commit, state: _state, dispatch },
    { id, stageId, position, lostReason, lockVersion }
  ) {
    const before = _state.records[id];
    // Not on the board (detail page opened by deep link): go straight to the server
    if (!before) {
      const { data } = await crmDealsAPI.move(id, {
        stage_id: stageId,
        lost_reason: lostReason,
        lock_version: lockVersion,
      });
      commit(types.UPSERT, data);
      dispatch('refreshForecast');
      return data;
    }
    const snapshot = {
      stageId: before.stage_id,
      position: before.position,
      order: JSON.parse(JSON.stringify(_state.order)),
    };
    commit(types.PLACE, { id, stageId, position });
    try {
      const { data } = await crmDealsAPI.move(id, {
        stage_id: stageId,
        // the board works with 0-based indexes, the API with 1-based positions
        position:
          position === undefined || position === null
            ? undefined
            : position + 1,
        lost_reason: lostReason,
        lock_version: before.lock_version,
      });
      commit(types.UPSERT, data);
      dispatch('refreshForecast');
      return data;
    } catch (error) {
      commit(types.PLACE, {
        id,
        stageId: snapshot.stageId,
        position: snapshot.position,
        order: snapshot.order,
      });
      throw error;
    }
  },

  async reopen({ commit, dispatch }, id) {
    const { data } = await crmDealsAPI.reopen(id);
    commit(types.UPSERT, data);
    dispatch('refreshForecast');
    return data;
  },

  async discard({ commit, dispatch }, id) {
    await crmDealsAPI.delete(id);
    commit(types.REMOVE, id);
    dispatch('refreshForecast');
  },

  async restore({ commit, dispatch }, id) {
    const { data } = await crmDealsAPI.restore(id);
    commit(types.UPSERT, data);
    dispatch('refreshForecast');
    return data;
  },

  async refreshForecast({ commit, state: _state }) {
    if (!_state.filters.pipelineId) return;
    try {
      const { data } = await crmDealsAPI.forecast({
        pipeline_id: _state.filters.pipelineId,
        assignee_id: _state.filters.assigneeId || undefined,
      });
      commit(types.SET_FORECAST, data);
    } catch (e) {
      // the board stays usable without fresh totals
    }
  },

  // ActionCable: another agent changed something
  onRemoteChange({ dispatch, state: _state }, payload) {
    if (!_state.uiFlags.hasFetched) return;
    if (
      payload.pipeline_id &&
      payload.pipeline_id !== _state.filters.pipelineId
    )
      return;
    dispatch('fetchBoard').catch(() => {});
  },
};

export const mutations = {
  [types.SET_BOARD](_state, { deals, counts, per_stage_limit: limit }) {
    const records = {};
    const order = {};
    deals.forEach(deal => {
      records[deal.id] = deal;
      (order[deal.stage_id] ||= []).push(deal.id);
    });
    Object.keys(order).forEach(stageId => {
      order[stageId] = sortIds(records, order[stageId]);
    });
    _state.records = records;
    _state.order = order;
    _state.counts = counts || {};
    if (limit) _state.perStageLimit = limit;
  },
  [types.SET_FORECAST](_state, forecast) {
    _state.forecast = forecast;
  },
  [types.UPSERT](_state, deal) {
    const previous = _state.records[deal.id];
    _state.records = { ..._state.records, [deal.id]: deal };
    if (deal.discarded_at) {
      mutations[types.REMOVE](_state, deal.id);
      return;
    }
    const order = { ..._state.order };
    if (previous && previous.stage_id !== deal.stage_id) {
      order[previous.stage_id] = (order[previous.stage_id] || []).filter(
        id => id !== deal.id
      );
    }
    if (!(order[deal.stage_id] || []).includes(deal.id)) {
      order[deal.stage_id] = [...(order[deal.stage_id] || []), deal.id];
    }
    order[deal.stage_id] = sortIds(_state.records, order[deal.stage_id]);
    _state.order = order;
  },
  [types.REMOVE](_state, id) {
    const deal = _state.records[id];
    const records = { ..._state.records };
    delete records[id];
    _state.records = records;
    if (deal) {
      _state.order = {
        ..._state.order,
        [deal.stage_id]: (_state.order[deal.stage_id] || []).filter(
          x => x !== id
        ),
      };
    }
  },
  // Put a card at a position in a stage (optimistic move, or a snap-back with a saved order)
  [types.PLACE](_state, { id, stageId, position, order: savedOrder }) {
    const deal = _state.records[id];
    if (!deal) return;
    if (savedOrder) {
      _state.order = savedOrder;
      _state.records = {
        ..._state.records,
        [id]: { ...deal, stage_id: stageId, position },
      };
      return;
    }
    const order = { ..._state.order };
    order[deal.stage_id] = (order[deal.stage_id] || []).filter(x => x !== id);
    const target = (order[stageId] || []).filter(x => x !== id);
    const index = Math.max(
      0,
      Math.min(position ?? target.length, target.length)
    );
    target.splice(index, 0, id);
    order[stageId] = target;
    const records = {
      ..._state.records,
      [id]: { ...deal, stage_id: stageId, position: index + 1 },
    };
    target.forEach((dealId, i) => {
      if (records[dealId])
        records[dealId] = { ...records[dealId], position: i + 1 };
    });
    _state.records = records;
    _state.order = order;
  },
  [types.SET_FILTERS](_state, filters) {
    _state.filters = { ..._state.filters, ...filters };
  },
  [types.SET_FLAGS](_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
};

export default { namespaced: true, state, getters, actions, mutations };
