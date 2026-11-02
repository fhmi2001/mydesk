<script setup>
// Custom (MyDesk): an open stage's follow-up rules (CONVERSATION_SALES_PLAN.md, phase 3), under its row in the pipeline
// editor: follow up a customer who goes quiet while the deal is in it, and a task its owner gets on entering it
// (after N days, with a title). Emits `update` with the changed field; the editor saves them with the stage.
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  stage: { type: Object, required: true },
});
const emit = defineEmits(['update']);
const { t } = useI18n();

const id = `crm-silence-${Math.random().toString(36).slice(2)}`;
</script>

<template>
  <div
    class="flex flex-wrap items-center gap-x-4 gap-y-2 ps-6 text-label-small text-n-slate-11"
  >
    <label :for="id" class="flex items-center gap-2 cursor-pointer">
      <input
        :id="id"
        type="checkbox"
        class="size-4 accent-n-brand"
        :checked="props.stage.silence_followup"
        @change="
          event => emit('update', { silence_followup: event.target.checked })
        "
      />
      {{ t('CRM.SETTINGS.FOLLOWUP.SILENCE') }}
    </label>
    <div class="flex flex-wrap items-center gap-2">
      <span>{{ t('CRM.SETTINGS.FOLLOWUP.TASK_AFTER') }}</span>
      <div class="w-16">
        <Input
          :model-value="String(props.stage.followup_task_days ?? '')"
          size="sm"
          inputmode="numeric"
          :aria-label="t('CRM.SETTINGS.FOLLOWUP.TASK_DAYS')"
          @update:model-value="
            value => emit('update', { followup_task_days: value })
          "
        />
      </div>
      <span>{{ t('CRM.SETTINGS.FOLLOWUP.DAYS_TITLED') }}</span>
      <div class="min-w-0 w-48">
        <Input
          :model-value="props.stage.followup_task_title || ''"
          size="sm"
          :placeholder="t('CRM.SETTINGS.FOLLOWUP.TASK_TITLE')"
          :aria-label="t('CRM.SETTINGS.FOLLOWUP.TASK_TITLE')"
          @update:model-value="
            value => emit('update', { followup_task_title: value })
          "
        />
      </div>
    </div>
  </div>
</template>
