<script setup>
// Custom (MyDesk): setup form for the Deewan SMS gateway (outbound only)
import { reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const state = reactive({
  inboxName: '',
  senderName: '',
  apiKey: '',
});

const uiFlags = useMapGetter('inboxes/getUIFlags');

const v$ = useVuelidate(
  {
    inboxName: { required },
    senderName: { required },
    apiKey: { required },
  },
  state
);

const formErrors = computed(() => ({
  inboxName: v$.value.inboxName.$error
    ? t('INBOX_MGMT.ADD.SMS.DEEWAN.INBOX_NAME.ERROR')
    : '',
  senderName: v$.value.senderName.$error
    ? t('INBOX_MGMT.ADD.SMS.DEEWAN.SENDER_NAME.ERROR')
    : '',
  apiKey: v$.value.apiKey.$error
    ? t('INBOX_MGMT.ADD.SMS.DEEWAN.API_KEY.ERROR')
    : '',
}));

async function createChannel() {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  try {
    const smsChannel = await store.dispatch('inboxes/createChannel', {
      name: state.inboxName.trim(),
      channel: {
        type: 'sms',
        provider: 'deewan',
        phone_number: state.senderName.trim(),
        provider_config: { api_key: state.apiKey.trim() },
      },
    });

    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: smsChannel.id },
    });
  } catch (error) {
    useAlert(t('INBOX_MGMT.ADD.SMS.API.ERROR_MESSAGE'));
  }
}
</script>

<template>
  <form class="flex flex-col gap-4 mx-0" @submit.prevent="createChannel">
    <p class="text-sm text-n-slate-11">
      {{ t('INBOX_MGMT.ADD.SMS.DEEWAN.OUTBOUND_NOTE') }}
    </p>

    <Input
      v-model="state.inboxName"
      :label="t('INBOX_MGMT.ADD.SMS.DEEWAN.INBOX_NAME.LABEL')"
      :placeholder="t('INBOX_MGMT.ADD.SMS.DEEWAN.INBOX_NAME.PLACEHOLDER')"
      :message="formErrors.inboxName"
      :message-type="formErrors.inboxName ? 'error' : 'info'"
      @blur="v$.inboxName.$touch"
    />

    <Input
      v-model="state.senderName"
      :label="t('INBOX_MGMT.ADD.SMS.DEEWAN.SENDER_NAME.LABEL')"
      :placeholder="t('INBOX_MGMT.ADD.SMS.DEEWAN.SENDER_NAME.PLACEHOLDER')"
      :message="
        formErrors.senderName || t('INBOX_MGMT.ADD.SMS.DEEWAN.SENDER_NAME.HELP')
      "
      :message-type="formErrors.senderName ? 'error' : 'info'"
      @blur="v$.senderName.$touch"
    />

    <Input
      v-model="state.apiKey"
      type="password"
      :label="t('INBOX_MGMT.ADD.SMS.DEEWAN.API_KEY.LABEL')"
      :placeholder="t('INBOX_MGMT.ADD.SMS.DEEWAN.API_KEY.PLACEHOLDER')"
      :message="formErrors.apiKey"
      :message-type="formErrors.apiKey ? 'error' : 'info'"
      @blur="v$.apiKey.$touch"
    />

    <div>
      <NextButton
        :is-loading="uiFlags.isCreating"
        :disabled="v$.$invalid"
        :label="t('INBOX_MGMT.ADD.SMS.DEEWAN.SUBMIT_BUTTON')"
        type="submit"
      />
    </div>
  </form>
</template>
