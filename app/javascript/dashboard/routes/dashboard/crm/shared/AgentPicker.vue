<script setup>
// Custom (MyDesk): pick an agent of the account (or none)
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Select from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
  noneLabel: { type: String, default: '' },
  ariaLabel: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
});

const model = defineModel({ type: [Number, String], default: '' });
const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');

onMounted(() => {
  if (!agents.value?.length) store.dispatch('agents/get');
});

const options = computed(() => [
  { value: '', label: props.noneLabel || t('CRM.COMMON.NO_ASSIGNEE') },
  ...(agents.value || []).map(agent => ({
    value: agent.id,
    label: agent.name,
  })),
]);

const value = computed({
  get: () =>
    model.value === null || model.value === undefined ? '' : model.value,
  set: v => {
    model.value = v === '' ? null : Number(v);
  },
});
</script>

<template>
  <Select
    v-model="value"
    :options="options"
    :disabled="disabled"
    :aria-label="ariaLabel"
  />
</template>
