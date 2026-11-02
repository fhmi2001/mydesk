/* global axios */
// Custom (MyDesk): the home screen's own numbers (Api::V1::Accounts::HomeController)
import ApiClient from './ApiClient';

class HomeAPI extends ApiClient {
  constructor() {
    super('home', { accountScoped: true });
  }

  // { late_count }: open conversations waiting an hour or more (the manager's only)
  waiting() {
    return axios.get(`${this.url}/waiting`);
  }
}

export default new HomeAPI();
