/* global axios */
/* eslint-disable max-classes-per-file -- one small client per CRM resource, kept together */
// Custom (MyDesk): the Sales CRM API clients (api/v1/accounts/:id/crm/*)
import ApiClient from '../ApiClient';

class CrmStatusAPI extends ApiClient {
  constructor() {
    super('crm/status', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }
}

class CrmPipelinesAPI extends ApiClient {
  constructor() {
    super('crm/pipelines', { accountScoped: true });
  }

  update(id, payload) {
    return axios.patch(`${this.url}/${id}`, payload);
  }
}

class CrmDealsAPI extends ApiClient {
  constructor() {
    super('crm/deals', { accountScoped: true });
  }

  get(params) {
    return axios.get(this.url, { params });
  }

  forecast(params) {
    return axios.get(`${this.url}/forecast`, { params });
  }

  discarded(params) {
    return axios.get(`${this.url}/discarded`, { params });
  }

  create(deal) {
    return axios.post(this.url, { deal });
  }

  update(id, deal) {
    return axios.patch(`${this.url}/${id}`, { deal });
  }

  move(id, payload) {
    return axios.patch(`${this.url}/${id}/move`, payload);
  }

  reopen(id) {
    return axios.post(`${this.url}/${id}/reopen`);
  }

  restore(id) {
    return axios.post(`${this.url}/${id}/restore`);
  }

  notes(id) {
    return axios.get(`${this.url}/${id}/notes`);
  }

  addNote(id, content) {
    return axios.post(`${this.url}/${id}/notes`, { content });
  }

  deleteNote(id, noteId) {
    return axios.delete(`${this.url}/${id}/notes/${noteId}`);
  }

  activities(id) {
    return axios.get(`${this.url}/${id}/activities`);
  }
}

class CrmTasksAPI extends ApiClient {
  constructor() {
    super('crm/tasks', { accountScoped: true });
  }

  get(params) {
    return axios.get(this.url, { params });
  }

  create(task) {
    return axios.post(this.url, { task });
  }

  update(id, task) {
    return axios.patch(`${this.url}/${id}`, { task });
  }

  complete(id) {
    return axios.post(`${this.url}/${id}/complete`);
  }

  reopen(id) {
    return axios.post(`${this.url}/${id}/reopen`);
  }
}

class CrmContactSummaryAPI extends ApiClient {
  constructor() {
    super('crm/contacts', { accountScoped: true });
  }

  get(contactId) {
    return axios.get(`${this.url}/${contactId}/summary`);
  }
}

class CrmReportsAPI extends ApiClient {
  constructor() {
    super('crm/reports', { accountScoped: true });
  }

  summary(params) {
    return axios.get(`${this.url}/summary`, { params });
  }

  funnel(params) {
    return axios.get(`${this.url}/funnel`, { params });
  }

  agents(params) {
    return axios.get(`${this.url}/agents`, { params });
  }

  lostReasons(params) {
    return axios.get(`${this.url}/lost_reasons`, { params });
  }

  timeline(params) {
    return axios.get(`${this.url}/timeline`, { params });
  }

  export(params) {
    return axios.get(`${this.url}/export`, { params, responseType: 'blob' });
  }
}

class CrmLostReasonsAPI extends ApiClient {
  constructor() {
    super('crm/lost_reasons', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(name) {
    return axios.post(this.url, { name });
  }

  update(id, name) {
    return axios.patch(`${this.url}/${id}`, { name });
  }

  reorder(ids) {
    return axios.patch(`${this.url}/reorder`, { ids });
  }
}

class CrmSettingsAPI extends ApiClient {
  constructor() {
    super('crm/settings', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  update(settings) {
    return axios.patch(this.url, { settings });
  }
}

export const crmStatusAPI = new CrmStatusAPI();
export const crmPipelinesAPI = new CrmPipelinesAPI();
export const crmDealsAPI = new CrmDealsAPI();
export const crmTasksAPI = new CrmTasksAPI();
export const crmContactSummaryAPI = new CrmContactSummaryAPI();
export const crmReportsAPI = new CrmReportsAPI();
export const crmSettingsAPI = new CrmSettingsAPI();
export const crmLostReasonsAPI = new CrmLostReasonsAPI();
