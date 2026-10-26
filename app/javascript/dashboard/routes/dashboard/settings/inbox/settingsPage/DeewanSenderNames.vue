<script setup>
// Custom (MyDesk): manage the approved Deewan sender names campaigns can choose from
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';

import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();
const uiFlags = useMapGetter('inboxes/getUIFlags');

// The default sender (the channel's phone_number) always stays first and is not editable here
const extraNames = inbox =>
  (inbox.sms_sender_names ?? []).filter(name => name !== inbox.phone_number);

const names = ref(extraNames(props.inbox));
watch(
  () => props.inbox.sms_sender_names,
  () => {
    names.value = extraNames(props.inbox);
  }
);

const isDirty = computed(
  () => JSON.stringify(names.value) !== JSON.stringify(extraNames(props.inbox))
);

const save = async () => {
  try {
    await store.dispatch('inboxes/updateInbox', {
      id: props.inbox.id,
      formData: false,
      channel: { sender_names: names.value },
    });
    useAlert(t('INBOX_MGMT.SMS_SENDER_NAMES.SUCCESS'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.SMS_SENDER_NAMES.ERROR'));
  }
};
</script>

<template>
  <SettingsFieldSection
    :label="t('INBOX_MGMT.SMS_SENDER_NAMES.TITLE')"
    :help-text="t('INBOX_MGMT.SMS_SENDER_NAMES.DESCRIPTION')"
  >
    <div class="flex flex-col gap-3">
      <p class="text-sm text-n-slate-11">
        {{
          t('INBOX_MGMT.SMS_SENDER_NAMES.DEFAULT', {
            name: inbox.phone_number,
          })
        }}
      </p>
      <div class="px-3 py-2 border rounded-xl border-n-weak">
        <TagInput
          v-model="names"
          :placeholder="t('INBOX_MGMT.SMS_SENDER_NAMES.PLACEHOLDER')"
          allow-create
          :auto-open-dropdown="false"
        />
      </div>
      <div>
        <NextButton
          :label="t('INBOX_MGMT.SMS_SENDER_NAMES.SAVE')"
          :is-loading="uiFlags.isUpdating"
          :disabled="!isDirty || uiFlags.isUpdating"
          @click="save"
        />
      </div>
    </div>
  </SettingsFieldSection>
</template>
