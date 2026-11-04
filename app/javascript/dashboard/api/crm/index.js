/* global axios */
/* eslint-disable max-classes-per-file -- one small client per CRM resource, kept together */
// Custom (MyDesk): the Sales CRM API clients (api/v1/accounts/:id/crm/*)
import ApiClient from '../ApiClient';

class CrmStatusAPI extends ApiClient {
  constructor() {
    super('crm/status', { accountScoped: true });
  }
}

class CrmPipelinesAPI extends ApiClient {
  constructor() {
    super('crm/pipelines', { accountScoped: true });
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

  // Follow the deal in another conversation of its customer, by display id
  linkConversation(id, conversationId) {
    return axios.post(`${this.url}/${id}/link_conversation`, {
      conversation_id: conversationId,
    });
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

  summary(contactId) {
    return axios.get(`${this.url}/${contactId}/summary`);
  }
}

// What the Sales section knows about one conversation, by its display id (lead source of its inbox, ...)
class CrmConversationsAPI extends ApiClient {
  constructor() {
    super('crm/conversations', { accountScoped: true });
  }

  // A draft the employee edits; nothing is saved by it
  summary(id) {
    return axios.post(`${this.url}/${id}/summary`);
  }
}

// The deal badges of the conversation cards, for up to 100 contacts at once
class CrmContactBadgesAPI extends ApiClient {
  constructor() {
    super('crm/contact_badges', { accountScoped: true });
  }

  get(contactIds) {
    return axios.get(this.url, { params: { contact_ids: contactIds } });
  }
}

class CrmSuggestionsAPI extends ApiClient {
  constructor() {
    super('crm/suggestions', { accountScoped: true });
  }

  dismiss(id) {
    return axios.post(`${this.url}/${id}/dismiss`);
  }

  // The AI draft of a deal's follow-up, won or lost message
  draft(id) {
    return axios.post(`${this.url}/${id}/draft`);
  }

  accept(id) {
    return axios.post(`${this.url}/${id}/accept`);
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

  stageWinRates(params) {
    return axios.get(`${this.url}/stage_win_rates`, { params });
  }

  export(params) {
    return axios.get(`${this.url}/export`, { params, responseType: 'blob' });
  }

  // One report of SalesCrm::Reports::Catalog, and the deals behind one of its numbers (`cell`)
  report(key, params) {
    return axios.get(`${this.url}/${key}`, { params });
  }

  drill(key, params) {
    return axios.get(`${this.url}/${key}/deals`, { params });
  }

  // A report as a file (file_format: xlsx or csv), for administrators
  download(key, params) {
    return axios.get(`${this.url}/${key}/download`, {
      params,
      responseType: 'blob',
    });
  }
}

class CrmLostReasonsAPI extends ApiClient {
  constructor() {
    super('crm/lost_reasons', { accountScoped: true });
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

// The managed lists: lead_source, product, competitor, region, industry
class CrmListItemsAPI extends ApiClient {
  constructor() {
    super('crm/list_items', { accountScoped: true });
  }

  get(list) {
    return axios.get(this.url, { params: { list } });
  }

  create(list, name) {
    return axios.post(this.url, { list, name });
  }

  update(id, name) {
    return axios.patch(`${this.url}/${id}`, { name });
  }

  archive(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  reorder(list, ids) {
    return axios.patch(`${this.url}/reorder`, { list, ids });
  }
}

class CrmTargetsAPI extends ApiClient {
  constructor() {
    super('crm/targets', { accountScoped: true });
  }

  get(month) {
    return axios.get(this.url, { params: { month } });
  }

  // One month's targets at once. amounts: { userId: '50000' }; a blank amount clears that employee's month
  save(month, amounts) {
    return axios.put(this.url, { month, amounts });
  }
}

class CrmSettingsAPI extends ApiClient {
  constructor() {
    super('crm/settings', { accountScoped: true });
  }

  // The account's settings are one record: saved as a whole patch, without an id
  save(settings) {
    return axios.patch(this.url, { settings });
  }
}

export const crmStatusAPI = new CrmStatusAPI();
export const crmPipelinesAPI = new CrmPipelinesAPI();
export const crmDealsAPI = new CrmDealsAPI();
export const crmTasksAPI = new CrmTasksAPI();
export const crmContactSummaryAPI = new CrmContactSummaryAPI();
export const crmConversationsAPI = new CrmConversationsAPI();
export const crmSuggestionsAPI = new CrmSuggestionsAPI();
export const crmContactBadgesAPI = new CrmContactBadgesAPI();
export const crmReportsAPI = new CrmReportsAPI();
export const crmSettingsAPI = new CrmSettingsAPI();
export const crmLostReasonsAPI = new CrmLostReasonsAPI();
export const crmListItemsAPI = new CrmListItemsAPI();
export const crmTargetsAPI = new CrmTargetsAPI();
