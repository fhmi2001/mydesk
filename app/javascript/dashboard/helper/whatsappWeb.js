// Custom (MyDesk): WhatsApp Web (QR) inboxes are API-channel inboxes whose webhook points at the
// Evolution API gateway (<gateway>/chatwoot/webhook/<instance>).
const GATEWAY_WEBHOOK = /\/chatwoot\/webhook\/[^/?#]+$/;

export const isWhatsappWebInbox = inbox =>
  inbox?.channel_type === 'Channel::Api' &&
  GATEWAY_WEBHOOK.test(inbox.webhook_url || '');
