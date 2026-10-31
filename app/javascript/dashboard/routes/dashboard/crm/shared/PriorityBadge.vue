<script setup>
// Custom (MyDesk): a deal's priority pill. High is amber (needs attention, per the signal colours);
// medium and low stay neutral so the board does not shout. Ruby is kept for lost and delete.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({ priority: { type: String, required: true } });
const { t } = useI18n();

const tone = computed(() =>
  props.priority === 'high'
    ? 'bg-n-amber-3 text-n-amber-11'
    : 'bg-n-slate-3 text-n-slate-11'
);
</script>

<template>
  <span
    class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-label-small font-medium"
    :class="tone"
  >
    <span
      v-if="priority === 'high'"
      class="i-lucide-flag size-3 shrink-0"
      aria-hidden="true"
    />
    <span class="sr-only">{{ t('CRM.DEALS.PRIORITY') }}:</span>
    {{ t(`CRM.DEALS.PRIORITIES.${priority}`) }}
  </span>
</template>
