<script setup>
// Custom (MyDesk): asks why a deal is lost before it lands in the lost stage; cancelling snaps the card back
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({ isLoading: { type: Boolean, default: false } });
const emit = defineEmits(['confirm', 'cancel']);
const { t } = useI18n();

const dialog = ref(null);
const reason = ref('');
const touched = ref(false);
const canConfirm = computed(() => reason.value.trim().length > 0);

const open = () => {
  reason.value = '';
  touched.value = false;
  dialog.value?.open();
};
const close = () => dialog.value?.close();

const confirm = () => {
  touched.value = true;
  if (!canConfirm.value) return;
  emit('confirm', reason.value.trim());
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
    <form @submit.prevent="confirm">
      <Input
        v-model="reason"
        :label="t('CRM.DEALS.LOST_DIALOG.REASON')"
        :placeholder="t('CRM.DEALS.LOST_DIALOG.PLACEHOLDER')"
        :message="
          touched && !canConfirm ? t('CRM.DEALS.LOST_DIALOG.REQUIRED') : ''
        "
        :message-type="touched && !canConfirm ? 'error' : 'info'"
        autofocus
      />
    </form>
  </Dialog>
</template>
