<script setup>
// Custom (MyDesk): create / edit a deal in a dialog. Presets (contact, assignee, conversation, stage)
// come from where the form was opened: the board, a column, or a conversation.
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import AgentPicker from '../shared/AgentPicker.vue';
import ContactPicker from '../shared/ContactPicker.vue';
import {
  emptyDealForm,
  dealToForm,
  validateDeal,
  buildDealPayload,
  isPastDate,
} from '../shared/dealHelpers';

const props = defineProps({
  pipelines: { type: Array, required: true },
  deal: { type: Object, default: null },
  presets: { type: Object, default: () => ({}) },
  isSaving: { type: Boolean, default: false },
});
const emit = defineEmits(['submit', 'close']);
const { t } = useI18n();

const dialog = ref(null);
const form = ref(emptyDealForm());
const errors = ref({});

const pipeline = computed(
  () =>
    props.pipelines.find(p => p.id === Number(form.value.pipeline_id)) ||
    props.pipelines[0]
);
const stageOptions = computed(() =>
  (pipeline.value?.stages || []).map(s => ({ value: s.id, label: s.name }))
);
const pipelineOptions = computed(() =>
  props.pipelines.map(p => ({ value: p.id, label: p.name }))
);
const closeDateInPast = computed(() => isPastDate(form.value.close_date));
const isEdit = computed(() => Boolean(props.deal));

const reset = () => {
  errors.value = {};
  if (props.deal) {
    form.value = dealToForm(props.deal);
    return;
  }
  const first = props.pipelines[0];
  form.value = emptyDealForm({
    pipeline_id: props.presets.pipeline_id || first?.id || null,
    stage_id:
      props.presets.stage_id ||
      first?.stages?.find(s => s.kind === 'open')?.id ||
      null,
    contact_id: props.presets.contact_id || null,
    contact_name: props.presets.contact_name || '',
    assignee_id: props.presets.assignee_id || null,
    conversation_id: props.presets.conversation_id || null,
  });
};

watch(
  () => form.value.pipeline_id,
  () => {
    if (!pipeline.value?.stages.some(s => s.id === form.value.stage_id)) {
      form.value.stage_id =
        pipeline.value?.stages.find(s => s.kind === 'open')?.id || null;
    }
  }
);

const open = () => {
  reset();
  dialog.value?.open();
};
const close = () => dialog.value?.close();

const submit = () => {
  const result = validateDeal(form.value);
  errors.value = result.errors;
  if (!result.valid) return;
  emit('submit', {
    payload: buildDealPayload(form.value),
    isEdit: isEdit.value,
    id: props.deal?.id,
  });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialog"
    :title="
      isEdit ? t('CRM.DEALS.FORM.EDIT_TITLE') : t('CRM.DEALS.FORM.NEW_TITLE')
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
        :label="t('CRM.DEALS.FORM.TITLE')"
        :placeholder="t('CRM.DEALS.FORM.TITLE_PLACEHOLDER')"
        :message="errors.title ? t(`CRM.DEALS.FORM.${errors.title}`) : ''"
        :message-type="errors.title ? 'error' : 'info'"
        autofocus
      />
      <div class="grid grid-cols-[minmax(0,1fr)_7rem] gap-3">
        <Input
          v-model="form.amount"
          :label="t('CRM.DEALS.FORM.AMOUNT')"
          inputmode="decimal"
          placeholder="0.00"
          :message="errors.amount ? t(`CRM.DEALS.FORM.${errors.amount}`) : ''"
          :message-type="errors.amount ? 'error' : 'info'"
        />
        <div class="flex flex-col gap-1">
          <label class="text-heading-3 text-n-slate-12">{{
            t('CRM.DEALS.FORM.CURRENCY')
          }}</label>
          <div
            class="flex items-center h-10 px-3 rounded-lg outline outline-1 -outline-offset-1 outline-n-weak bg-n-alpha-black2 text-body-main text-n-slate-11"
          >
            {{ pipeline?.currency || 'SAR' }}
          </div>
        </div>
      </div>
      <div v-if="pipelines.length > 1 && !isEdit" class="flex flex-col gap-1">
        <label class="text-heading-3 text-n-slate-12">{{
          t('CRM.DEALS.PIPELINE')
        }}</label>
        <Select v-model="form.pipeline_id" :options="pipelineOptions" />
      </div>
      <div v-if="!isEdit" class="flex flex-col gap-1">
        <label class="text-heading-3 text-n-slate-12">{{
          t('CRM.DEALS.FORM.STAGE')
        }}</label>
        <Select v-model="form.stage_id" :options="stageOptions" />
      </div>
      <div class="flex flex-col gap-1">
        <label class="text-heading-3 text-n-slate-12">{{
          t('CRM.DEALS.FORM.CONTACT')
        }}</label>
        <ContactPicker
          v-model="form.contact_id"
          :contact-name="form.contact_name"
          @select="c => (form.contact_name = c?.name || '')"
        />
      </div>
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div class="flex flex-col gap-1">
          <label class="text-heading-3 text-n-slate-12">{{
            t('CRM.DEALS.FORM.ASSIGNEE')
          }}</label>
          <AgentPicker v-model="form.assignee_id" />
        </div>
        <Input
          v-model="form.close_date"
          type="date"
          :label="t('CRM.DEALS.FORM.CLOSE_DATE')"
          :message="closeDateInPast ? t('CRM.DEALS.FORM.CLOSE_DATE_PAST') : ''"
          message-type="info"
        />
      </div>
      <TextArea
        v-model="form.description"
        :label="t('CRM.DEALS.FORM.DESCRIPTION')"
        :max-length="5000"
        auto-height
      />
    </form>
  </Dialog>
</template>
