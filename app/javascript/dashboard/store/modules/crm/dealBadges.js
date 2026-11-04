// Custom (MyDesk): the deal badges of the conversation cards (CONVERSATION_SALES_PLAN.md). Cards ask for their
// contact; the asks of one list page go out together a moment later (up to 100 contacts a request), and a contact
// already known is not asked again. A deal changing anywhere (crm.deal_* over ActionCable) asks again for all of them.
import { reactive } from 'vue';
import { crmContactBadgesAPI } from 'dashboard/api/crm';

const BATCH = 100;
const WAIT_MS = 50;

// contact id (string) → { count, total_cents, currency, stage } or null when the user may see no open deal
export const badges = reactive({});
const queued = new Set();
let timer = null;

const schedule = () => {
  timer ||= setTimeout(flush, WAIT_MS); // eslint-disable-line no-use-before-define
};

const flush = async () => {
  timer = null;
  const ids = [...queued].slice(0, BATCH);
  ids.forEach(id => queued.delete(id));
  if (!ids.length) return;
  try {
    const { data } = await crmContactBadgesAPI.get(ids);
    ids.forEach(id => {
      badges[String(id)] = data.badges?.[id] || null;
    });
  } catch {
    ids.forEach(id => {
      badges[String(id)] = null;
    });
  }
  if (queued.size) schedule();
};

export const requestBadge = contactId => {
  const id = Number(contactId);
  if (!id || String(id) in badges || queued.has(id)) return;
  queued.add(id);
  schedule();
};

export const refreshBadges = () => {
  Object.keys(badges).forEach(key => {
    delete badges[key];
    queued.add(Number(key));
  });
  if (queued.size) schedule();
};

// For tests
export const resetBadges = () => {
  Object.keys(badges).forEach(key => delete badges[key]);
  queued.clear();
  clearTimeout(timer);
  timer = null;
};
