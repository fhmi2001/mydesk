<script setup>
// Custom (MyDesk): the settings of the Sales actions in an automation rule (CONVERSATION_SALES_PLAN.md),
// rendered by Chatwoot's AutomationActionInput for inputType 'crm_action'. The value is one object:
//   suggest_crm_deal { title }  ·  create_crm_task { title, kind, hours }  ·  move_crm_deal { stage_id }
// A move offers every stage but the lost ones, since losing a deal needs a reason the rule cannot give.
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
  actionName: { type: String, required: true },
  modelValue: { type: Object, default: () => ({}) },
});
const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();
const store = useStore();
const pipelines = useMapGetter('crm/pipelines/all');

onMounted(() => {
  if (props.actionName === 'move_crm_deal' && !pipelines.value?.length) {
    store.dispatch('crm/pipelines/fetch');
  }
});

const value = computed(() => props.modelValue || {});
const set = (key, newValue) =>
  emit('update:modelValue', { ...value.value, [key]: newValue });

const kindOptions = computed(() => [
  { value: 'task', label: t('CRM.AUTOMATION.KINDS.task') },
  { value: 'call', label: t('CRM.AUTOMATION.KINDS.call') },
  { value: 'meeting', label: t('CRM.AUTOMATION.KINDS.meeting') },
]);
const stageOptions = computed(() =>
  (pipelines.value || []).map(pipeline => ({
    label: pipeline.name,
    options: pipeline.stages
      .filter(stage => stage.kind !== 'lost')
      .map(stage => ({ value: stage.id, label: stage.name })),
  }))
);
</script>

<template>
  <div class="flex flex-col gap-2">
    <Input
      v-if="actionName !== 'move_crm_deal'"
      :model-value="value.title || ''"
      size="sm"
      :placeholder="
        actionName === 'suggest_crm_deal'
          ? t('CRM.AUTOMATION.DEAL_TITLE')
          : t('CRM.AUTOMATION.TASK_TITLE')
      "
      @update:model-value="title => set('title', title)"
    />
    <div
      v-if="actionName === 'create_crm_task'"
      class="flex flex-wrap items-center gap-2"
    >
      <Select
        :model-value="value.kind || 'task'"
        :options="kindOptions"
        :aria-label="t('CRM.AUTOMATION.KIND')"
        @update:model-value="kind => set('kind', kind)"
      />
      <Input
        :model-value="String(value.hours ?? '')"
        size="sm"
        inputmode="numeric"
        class="w-28"
        :placeholder="t('CRM.AUTOMATION.HOURS')"
        @update:model-value="hours => set('hours', Number(hours) || 0)"
      />
      <span class="text-label-small text-n-slate-11">
        {{ t('CRM.AUTOMATION.HOURS_HINT') }}
      </span>
    </div>
    <template v-if="actionName === 'move_crm_deal'">
      <Select
        :model-value="value.stage_id || ''"
        :groups="stageOptions"
        :placeholder="t('CRM.AUTOMATION.STAGE')"
        :aria-label="t('CRM.AUTOMATION.STAGE')"
        @update:model-value="stageId => set('stage_id', Number(stageId))"
      />
      <p class="text-label-small text-n-slate-11">
        {{ t('CRM.AUTOMATION.MOVE_HINT') }}
      </p>
    </template>
    <p
      v-if="actionName === 'suggest_crm_deal'"
      class="text-label-small text-n-slate-11"
    >
      {{ t('CRM.AUTOMATION.SUGGEST_HINT') }}
    </p>
  </div>
</template>
