/* global axios */

import ApiClient from './ApiClient';

class CampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns', { accountScoped: true });
  }

  analyticsMetrics(id) {
    return axios.get(`${this.url}/${id}/analytics/metrics`);
  }

  analyticsContacts(id, { status, page } = {}) {
    return axios.get(`${this.url}/${id}/analytics/contacts`, {
      params: { status, page },
    });
  }

  // Custom (MyDesk): clean typed/uploaded numbers and count label contacts before an SMS campaign is created
  previewSmsRecipients({ numbers, file, labelIds }, { signal } = {}) {
    const formData = new FormData();
    if (numbers) formData.append('numbers', numbers);
    if (file) formData.append('file', file);
    (labelIds ?? []).forEach(id => formData.append('label_ids[]', id));
    return axios.post(`${this.url}/sms_recipients/preview`, formData, {
      signal,
    });
  }

  // Custom (MyDesk): the numbers of an SMS campaign with their result and provider ids, 50 per page
  smsRecipients(id, { page, status } = {}) {
    return axios.get(`${this.url}/${id}/sms_recipients`, {
      params: { page, status },
    });
  }

  // Custom (MyDesk): ask the SMS provider, in the background, whether the sent numbers received the message
  syncSmsDelivery(id) {
    return axios.post(`${this.url}/${id}/sms_recipients/sync_delivery`);
  }

  // Custom (MyDesk): conversations a live chat campaign started, newest first, 25 per page
  conversations(id, { page } = {}) {
    return axios.get(`${this.url}/${id}/conversations`, { params: { page } });
  }
}

export default new CampaignsAPI();
