/* global axios */

import ApiClient from '../ApiClient';

// Custom (MyDesk): connect a Salla store and read the events it sends
class SallaAPI extends ApiClient {
  constructor() {
    super('integrations/salla', { accountScoped: true });
  }

  authorizeUrl() {
    return axios.get(`${this.url}/auth`);
  }

  events() {
    return axios.get(`${this.url}/events`);
  }
}

export default new SallaAPI();
