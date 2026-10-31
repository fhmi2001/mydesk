<script setup>
// Custom (MyDesk): asks why a deal is lost before it lands in the lost stage: a reason from the account's
// list (Sales settings) plus optional notes. Cancelling snaps the card back.
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { crmLostReasonsAPI } from 'dashboard/api/crm';

const props = defineProps({ isLoading: { type: Boolean, default: false } });
const emit = defineEmits(['confirm', 'cancel']);
const { t } = useI18n();

const dialog = ref(null);
const reasons = ref([]);
const reason = ref('');
const note = ref('');
const touched = ref(false);

const options = computed(() =>
  reasons.value.map(r => ({ value: r.name, label: r.name }))
);
const canConfirm = computed(() => reason.value.trim().length > 0);

const loadReasons = async () => {
  try {
    const { data } = await crmLostReasonsAPI.get();
    reasons.value = data;
  } catch (e) {
    reasons.value = [];
  }
};

const open = () => {
  reason.value = '';
  note.value = '';
  touched.value = false;
  loadReasons();
  dialog.value?.open();
};
const close = () => dialog.value?.close();

const confirm = () => {
  touched.value = true;
  if (!canConfirm.value) return;
  emit('confirm', { reason: reason.value.trim(), note: note.value.trim() });
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialog"
    type="alert"
    :title="t('CRM.DEALS.LOST_DIALOG.TITLE')"
    :description="t('CRM.DEALS.LOST_DIALOG.BODY')"
    :confirm-button-label="t('CRM.DEALS.LOST_DIALOG.CONFIRM')"
    :cancel-button-label="t('CRM.COMMON.CANCEL')"
    :disable-confirm-button="!canConfirm"
    :is-loading="props.isLoading"
    @confirm="confirm"
    @close="emit('cancel')"
  >
    <form class="flex flex-col gap-4" @submit.prevent="confirm">
      <div class="flex flex-col gap-1">
        <label class="text-heading-3 text-n-slate-12">
          {{ t('CRM.DEALS.LOST_DIALOG.REASON') }}
        </label>
        <Select
          v-model="reason"
          :options="options"
          :placeholder="t('CRM.DEALS.LOST_DIALOG.PLACEHOLDER')"
          :error="
            touched && !canConfirm ? t('CRM.DEALS.LOST_DIALOG.REQUIRED') : ''
          "
        />
      </div>
      <TextArea
        v-model="note"
        :label="t('CRM.DEALS.LOST_DIALOG.NOTE')"
        :placeholder="t('CRM.DEALS.LOST_DIALOG.NOTE_PLACEHOLDER')"
        :max-length="2000"
        auto-height
      />
    </form>
  </Dialog>
</template>
