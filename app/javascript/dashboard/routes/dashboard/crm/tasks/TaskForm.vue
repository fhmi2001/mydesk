<script setup>
// Custom (MyDesk): create / edit a task in a dialog; due date entered in the account's time zone
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import AgentPicker from '../shared/AgentPicker.vue';
import ContactPicker from '../shared/ContactPicker.vue';
import { useCrmFormat } from '../shared/useCrmFormat';
import {
  toLocalInputValue,
  fromLocalInputValue,
} from 'dashboard/helper/crmFormat';

const props = defineProps({
  task: { type: Object, default: null },
  presets: { type: Object, default: () => ({}) },
  isSaving: { type: Boolean, default: false },
});
const emit = defineEmits(['submit', 'close']);
const { t } = useI18n();
const { timezone } = useCrmFormat();

const dialog = ref(null);
const form = ref({});
const titleError = ref('');
const isEdit = computed(() => Boolean(props.task));

const TASK_KINDS = ['task', 'call', 'meeting'];
const kindOptions = computed(() =>
  TASK_KINDS.map(kind => ({ value: kind, label: t(`CRM.TASKS.KINDS.${kind}`) }))
);

const reset = () => {
  titleError.value = '';
  const tz = timezone.value;
  if (props.task) {
    form.value = {
      title: props.task.title,
      kind: props.task.kind || 'task',
      description: props.task.description || '',
      due_local: toLocalInputValue(props.task.due_at, tz),
      assignee_id: props.task.assignee?.id ?? null,
      contact_id: props.task.contact?.id ?? null,
      contact_name: props.task.contact?.name || '',
      deal_id: props.task.deal?.id ?? null,
      deal_title: props.task.deal?.title || '',
    };
    return;
  }
  form.value = {
    title: '',
    kind: props.presets.kind || 'task',
    description: '',
    due_local: '',
    assignee_id: props.presets.assignee_id ?? null,
    contact_id: props.presets.contact_id ?? null,
    contact_name: props.presets.contact_name || '',
    deal_id: props.presets.deal_id ?? null,
    deal_title: props.presets.deal_title || '',
    conversation_id: props.presets.conversation_id ?? null,
  };
};

const open = () => {
  reset();
  dialog.value?.open();
};
const close = () => dialog.value?.close();

const submit = () => {
  if (!form.value.title.trim()) {
    titleError.value = t('CRM.TASKS.FORM.TITLE_REQUIRED');
    return;
  }
  emit('submit', {
    id: props.task?.id,
    isEdit: isEdit.value,
    payload: {
      title: form.value.title.trim(),
      kind: form.value.kind || 'task',
      description: form.value.description,
      due_at: fromLocalInputValue(form.value.due_local, timezone.value),
      assignee_id: form.value.assignee_id || null,
      contact_id: form.value.contact_id || null,
      deal_id: form.value.deal_id || null,
      conversation_id: form.value.conversation_id || undefined,
    },
  });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialog"
    :title="
      isEdit ? t('CRM.TASKS.FORM.EDIT_TITLE') : t('CRM.TASKS.FORM.NEW_TITLE')
    "
    :confirm-button-label="t('CRM.COMMON.SAVE')"
    :cancel-button-label="t('CRM.COMMON.CANCEL')"
    :is-loading="isSaving"
    @confirm="submit"
    @close="emit('close')"
  >
    <form class="flex flex-col gap-4" @submit.prevent="submit">
      <Input
        v-model="form.title"
        :label="t('CRM.TASKS.FORM.TITLE')"
        :placeholder="t('CRM.TASKS.FORM.TITLE_PLACEHOLDER')"
        :message="titleError"
        :message-type="titleError ? 'error' : 'info'"
        autofocus
      />
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-[10rem_minmax(0,1fr)]">
        <div class="flex flex-col gap-1">
          <span class="text-heading-3 text-n-slate-12" aria-hidden="true">
            {{ t('CRM.TASKS.FORM.KIND') }}
          </span>
          <Select
            v-model="form.kind"
            :options="kindOptions"
            :aria-label="t('CRM.TASKS.FORM.KIND')"
          />
        </div>
        <Input
          v-model="form.due_local"
          type="datetime-local"
          :label="t('CRM.TASKS.FORM.DUE_AT')"
        />
      </div>
      <!-- The pickers render buttons, not inputs, so each field is a labelled group -->
      <div
        class="flex flex-col gap-1"
        role="group"
        aria-labelledby="crm-task-assignee"
      >
        <span id="crm-task-assignee" class="text-heading-3 text-n-slate-12">
          {{ t('CRM.TASKS.FORM.ASSIGNEE') }}
        </span>
        <AgentPicker
          v-model="form.assignee_id"
          :aria-label="t('CRM.TASKS.FORM.ASSIGNEE')"
        />
      </div>
      <div
        class="flex flex-col gap-1"
        role="group"
        aria-labelledby="crm-task-contact"
      >
        <span id="crm-task-contact" class="text-heading-3 text-n-slate-12">
          {{ t('CRM.TASKS.FORM.CONTACT') }}
        </span>
        <ContactPicker
          v-model="form.contact_id"
          :contact-name="form.contact_name"
          @select="c => (form.contact_name = c?.name || '')"
        />
      </div>
      <div
        v-if="form.deal_title"
        class="flex flex-col gap-1"
        role="group"
        aria-labelledby="crm-task-deal"
      >
        <span id="crm-task-deal" class="text-heading-3 text-n-slate-12">
          {{ t('CRM.TASKS.FORM.DEAL') }}
        </span>
        <div
          class="flex items-center h-10 px-3 rounded-lg text-body-main bg-n-alpha-black2 text-n-slate-11 outline outline-1 -outline-offset-1 outline-n-weak"
        >
          {{ form.deal_title }}
        </div>
      </div>
      <TextArea
        v-model="form.description"
        :label="t('CRM.TASKS.FORM.DESCRIPTION')"
        :max-length="5000"
        auto-height
      />
    </form>
  </Dialog>
</template>
