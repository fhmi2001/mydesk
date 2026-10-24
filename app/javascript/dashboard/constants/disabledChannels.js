// Custom (MyDesk): channel keys hidden from the "add inbox" and onboarding lists.
// Existing inboxes of these types keep working; only creating new ones is hidden.
export const DISABLED_CHANNEL_KEYS = ['line'];

export const isChannelEnabled = key => !DISABLED_CHANNEL_KEYS.includes(key);
