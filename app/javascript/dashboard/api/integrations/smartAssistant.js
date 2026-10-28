/* global axios */

import ApiClient from '../ApiClient';

// Custom (MyDesk): the account's smart assistant, its knowledge base and the test chat
class SmartAssistantAPI extends ApiClient {
  constructor() {
    super('integrations/smart_assistant', { accountScoped: true });
  }

  show() {
    return axios.get(this.url);
  }

  save(settings) {
    return axios.patch(this.url, { smart_assistant: settings });
  }

  test(messages) {
    return axios.post(`${this.url}/test`, { messages });
  }

  sources() {
    return axios.get(`${this.url}/sources`);
  }

  // A FormData body, so documents upload with the other fields
  createSource(formData) {
    return axios.post(`${this.url}/sources`, formData);
  }

  deleteSource(id) {
    return axios.delete(`${this.url}/sources/${id}`);
  }

  syncSource(id) {
    return axios.post(`${this.url}/sources/${id}/sync`);
  }
}

export default new SmartAssistantAPI();
