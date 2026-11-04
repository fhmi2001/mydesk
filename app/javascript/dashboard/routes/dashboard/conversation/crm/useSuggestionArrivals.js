// Custom (MyDesk): a Sales suggestion created in the background (the assistant, an automation rule, the hourly
// follow-up) reaches the open conversation panel at once: crm.suggestion_created over ActionCable is put on the bus
// (dashboard/helper/actionCable.js), and the panel showing that conversation calls back to reload its suggestions.
import { onMounted, onUnmounted } from 'vue';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

export const useSuggestionArrivals = (conversationId, onArrive) => {
  const handler = data => {
    const current = conversationId();
    if (current && String(data?.conversation_display_id) === String(current)) {
      onArrive(data);
    }
  };
  onMounted(() => emitter.on(BUS_EVENTS.CRM_SUGGESTION_CREATED, handler));
  onUnmounted(() => emitter.off(BUS_EVENTS.CRM_SUGGESTION_CREATED, handler));
};
