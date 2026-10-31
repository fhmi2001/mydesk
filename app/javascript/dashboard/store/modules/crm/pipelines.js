// Custom (MyDesk): the account's pipelines and stages
import { crmPipelinesAPI } from 'dashboard/api/crm';

export const types = {
  SET: 'crm/pipelines/SET',
  UPSERT: 'crm/pipelines/UPSERT',
  REMOVE: 'crm/pipelines/REMOVE',
  SET_FLAGS: 'crm/pipelines/SET_FLAGS',
};

export const state = {
  records: [],
  uiFlags: { isFetching: false, hasFetched: false, isSaving: false },
};

export const getters = {
  all: _state => _state.records,
  byId: _state => id => _state.records.find(p => p.id === Number(id)),
  first: _state => _state.records[0],
  getUIFlags: _state => _state.uiFlags,
};

export const actions = {
  async fetch({ commit }) {
    commit(types.SET_FLAGS, { isFetching: true });
    try {
      const { data } = await crmPipelinesAPI.get();
      commit(types.SET, data);
    } finally {
      commit(types.SET_FLAGS, { isFetching: false, hasFetched: true });
    }
  },
  async create({ commit }, payload) {
    commit(types.SET_FLAGS, { isSaving: true });
    try {
      const { data } = await crmPipelinesAPI.create(payload);
      commit(types.UPSERT, data);
      return data;
    } finally {
      commit(types.SET_FLAGS, { isSaving: false });
    }
  },
  async update({ commit }, { id, ...payload }) {
    commit(types.SET_FLAGS, { isSaving: true });
    try {
      const { data } = await crmPipelinesAPI.update(id, payload);
      commit(types.UPSERT, data);
      return data;
    } finally {
      commit(types.SET_FLAGS, { isSaving: false });
    }
  },
  async delete({ commit }, id) {
    await crmPipelinesAPI.delete(id);
    commit(types.REMOVE, id);
  },
};

export const mutations = {
  [types.SET](_state, records) {
    _state.records = records;
  },
  [types.UPSERT](_state, record) {
    const index = _state.records.findIndex(p => p.id === record.id);
    if (index === -1) _state.records.push(record);
    else _state.records.splice(index, 1, record);
  },
  [types.REMOVE](_state, id) {
    _state.records = _state.records.filter(p => p.id !== Number(id));
  },
  [types.SET_FLAGS](_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
};

export default { namespaced: true, state, getters, actions, mutations };
