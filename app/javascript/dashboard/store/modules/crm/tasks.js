// Custom (MyDesk): the tasks page tabs and the overdue badge
import { crmTasksAPI } from 'dashboard/api/crm';

export const types = {
  SET: 'crm/tasks/SET',
  UPSERT: 'crm/tasks/UPSERT',
  REMOVE: 'crm/tasks/REMOVE',
  SET_SCOPE: 'crm/tasks/SET_SCOPE',
  SET_FLAGS: 'crm/tasks/SET_FLAGS',
};

export const state = {
  records: [],
  total: 0,
  scope: 'mine',
  uiFlags: {
    isFetching: false,
    hasFetched: false,
    isSaving: false,
    isUnavailable: false,
  },
};

export const getters = {
  all: _state => _state.records,
  total: _state => _state.total,
  scope: _state => _state.scope,
  getUIFlags: _state => _state.uiFlags,
};

const belongsToScope = (task, scope) => {
  if (scope === 'done') return task.status === 'done';
  return task.status === 'open';
};

export const actions = {
  async fetch({ commit, dispatch }, { scope, contactId, dealId, page } = {}) {
    if (scope) commit(types.SET_SCOPE, scope);
    commit(types.SET_FLAGS, { isFetching: true });
    try {
      const { data } = await crmTasksAPI.get({
        scope: scope || undefined,
        contact_id: contactId,
        deal_id: dealId,
        page,
      });
      commit(types.SET, data);
      dispatch('crm/status/setOverdueCount', data.overdue_count, {
        root: true,
      });
      commit(types.SET_FLAGS, {
        isFetching: false,
        hasFetched: true,
        isUnavailable: false,
      });
    } catch (error) {
      commit(types.SET_FLAGS, {
        isFetching: false,
        hasFetched: true,
        isUnavailable: error?.response?.status >= 500 || !error?.response,
      });
      throw error;
    }
  },

  async create({ commit, dispatch }, task) {
    commit(types.SET_FLAGS, { isSaving: true });
    try {
      const { data } = await crmTasksAPI.create(task);
      commit(types.UPSERT, data);
      dispatch('crm/status/fetch', null, { root: true });
      return data;
    } finally {
      commit(types.SET_FLAGS, { isSaving: false });
    }
  },

  async update({ commit, dispatch }, { id, ...task }) {
    commit(types.SET_FLAGS, { isSaving: true });
    try {
      const { data } = await crmTasksAPI.update(id, task);
      commit(types.UPSERT, data);
      dispatch('crm/status/fetch', null, { root: true });
      return data;
    } finally {
      commit(types.SET_FLAGS, { isSaving: false });
    }
  },

  async complete({ commit, dispatch }, id) {
    const { data } = await crmTasksAPI.complete(id);
    commit(types.UPSERT, data);
    dispatch('crm/status/fetch', null, { root: true });
    return data;
  },

  async reopen({ commit, dispatch }, id) {
    const { data } = await crmTasksAPI.reopen(id);
    commit(types.UPSERT, data);
    dispatch('crm/status/fetch', null, { root: true });
    return data;
  },

  async delete({ commit, dispatch }, id) {
    await crmTasksAPI.delete(id);
    commit(types.REMOVE, id);
    dispatch('crm/status/fetch', null, { root: true });
  },

  onRemoteChange({ dispatch, state: _state }) {
    dispatch('crm/status/fetch', null, { root: true });
    if (_state.uiFlags.hasFetched)
      dispatch('fetch', { scope: _state.scope }).catch(() => {});
  },
};

export const mutations = {
  [types.SET](_state, { tasks, total }) {
    _state.records = tasks;
    _state.total = total;
  },
  [types.UPSERT](_state, task) {
    const index = _state.records.findIndex(t => t.id === task.id);
    if (!belongsToScope(task, _state.scope)) {
      if (index !== -1) _state.records.splice(index, 1);
      return;
    }
    if (index === -1) _state.records.unshift(task);
    else _state.records.splice(index, 1, task);
  },
  [types.REMOVE](_state, id) {
    _state.records = _state.records.filter(t => t.id !== id);
  },
  [types.SET_SCOPE](_state, scope) {
    _state.scope = scope;
  },
  [types.SET_FLAGS](_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
};

export default { namespaced: true, state, getters, actions, mutations };
