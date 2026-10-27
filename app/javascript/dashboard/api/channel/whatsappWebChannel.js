/* global axios */
import ApiClient from '../ApiClient';

// Custom (MyDesk): WhatsApp Web (QR) numbers served by the Evolution API gateway
class WhatsappWebChannel extends ApiClient {
  constructor() {
    super('whatsapp_web', { accountScoped: true });
  }

  getStatus() {
    return axios.get(this.url);
  }

  createInbox(name) {
    return axios.post(this.url, { name });
  }

  getConnection(inboxId) {
    return axios.get(`${this.url}/inboxes/${inboxId}/connection`);
  }

  disconnect(inboxId) {
    return axios.delete(`${this.url}/inboxes/${inboxId}/connection`);
  }
}

export default new WhatsappWebChannel();
