<script setup>
// Custom (MyDesk): open / won / lost pill
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({ status: { type: String, required: true } });
const { t } = useI18n();

const tone = computed(
  () =>
    ({
      open: 'bg-n-blue-3 text-n-blue-11',
      won: 'bg-n-teal-3 text-n-teal-11',
      lost: 'bg-n-ruby-3 text-n-ruby-11',
    })[props.status] || 'bg-n-slate-3 text-n-slate-11'
);
const label = computed(() => t(`CRM.COMMON.${props.status.toUpperCase()}`));
</script>

<template>
  <span
    class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium"
    :class="tone"
  >
    {{ label }}
  </span>
</template>
