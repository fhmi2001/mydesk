// Custom (MyDesk): is the Sales CRM on for this account, my overdue tasks, and the account's CRM settings
import { crmStatusAPI } from 'dashboard/api/crm';

export const types = {
  SET: 'crm/status/SET',
  SET_OVERDUE: 'crm/status/SET_OVERDUE',
  SET_FLAGS: 'crm/status/SET_FLAGS',
  RESET: 'crm/status/RESET',
};

const initialState = () => ({
  enabled: false,
  isAdmin: false,
  overdueCount: 0,
  settings: {
    agents_see_own_deals_only: false,
    default_currency: 'SAR',
    timezone: 'Asia/Riyadh',
  },
  uiFlags: { isFetching: false, hasFetched: false, isUnavailable: false },
});

export const state = initialState();

export const getters = {
  isEnabled: _state => _state.enabled,
  isAdmin: _state => _state.isAdmin,
  overdueCount: _state => _state.overdueCount,
  settings: _state => _state.settings,
  timezone: _state => _state.settings.timezone,
  getUIFlags: _state => _state.uiFlags,
};

export const actions = {
  async fetch({ commit }) {
    commit(types.SET_FLAGS, { isFetching: true });
    try {
      const { data } = await crmStatusAPI.get();
      commit(types.SET, data);
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
    }
  },
  setOverdueCount({ commit }, count) {
    commit(types.SET_OVERDUE, count);
  },
  reset({ commit }) {
    commit(types.RESET);
  },
};

export const mutations = {
  [types.SET](_state, data) {
    _state.enabled = Boolean(data.enabled);
    _state.isAdmin = Boolean(data.is_admin);
    _state.overdueCount = Number(data.overdue_count || 0);
    if (data.settings)
      _state.settings = { ..._state.settings, ...data.settings };
  },
  [types.SET_OVERDUE](_state, count) {
    _state.overdueCount = Number(count || 0);
  },
  [types.SET_FLAGS](_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
  [types.RESET](_state) {
    Object.assign(_state, initialState());
  },
};

export default { namespaced: true, state, getters, actions, mutations };
