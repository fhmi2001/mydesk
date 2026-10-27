<script setup>
// Custom (MyDesk): input of the "send a message through a channel" automation action: the inbox the
// message goes out from, and the message ({{contact.name}} and the other variables work in it).
// Only channels that can start a conversation are offered; AutomationRules::SendViaInboxService
// applies the same list on the server.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import {
  INBOX_TYPES,
  getInboxIconByType,
  isWhatsappWebMedium,
} from 'dashboard/helper/inbox';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';

const props = defineProps({
  // { inbox_id, message }; an edited rule hands it over as [{ inbox_id, message }]
  modelValue: { type: [Object, Array], default: null },
  dropdownMaxHeight: { type: String, default: 'max-h-80' },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const inboxes = useMapGetter('inboxes/getInboxes');

const value = computed(
  () =>
    (Array.isArray(props.modelValue)
      ? props.modelValue[0]
      : props.modelValue) || {}
);

const channelKind = inbox => {
  const { channel_type: type, medium } = inbox;
  if (type === INBOX_TYPES.SMS) return 'SMS';
  if (type === INBOX_TYPES.TWILIO && medium === 'sms') return 'SMS';
  if (type === INBOX_TYPES.EMAIL) return 'EMAIL';
  if (isWhatsappWebMedium(type, medium)) return 'WHATSAPP_WEB';
  return null;
};

const channelOptions = computed(() =>
  (inboxes.value || [])
    .map(inbox => ({ inbox, kind: channelKind(inbox) }))
    .filter(({ kind }) => kind)
    .map(({ inbox, kind }) => ({
      id: inbox.id,
      name: `${inbox.name} · ${t(`AUTOMATION.ACTION.INBOX_MESSAGE.KINDS.${kind}`)}`,
      icon: getInboxIconByType(inbox.channel_type, inbox.medium, 'line'),
    }))
);

const update = changes => {
  emit('update:modelValue', {
    inbox_id: value.value.inbox_id ?? null,
    message: value.value.message ?? '',
    ...changes,
  });
};

const selectedChannel = computed({
  get: () =>
    channelOptions.value.find(option => option.id === value.value.inbox_id) ||
    null,
  set: option => update({ inbox_id: option?.id ?? null }),
});

const message = computed({
  get: () => value.value.message || '',
  set: text => update({ message: text }),
});
</script>

<template>
  <div class="flex flex-col gap-2">
    <p
      v-if="!channelOptions.length"
      class="mb-0 text-sm rounded-lg px-3 py-2 bg-n-amber-3 text-n-amber-11"
    >
      {{ t('AUTOMATION.ACTION.INBOX_MESSAGE.NO_CHANNELS') }}
    </p>
    <template v-else>
      <SingleSelect
        v-model="selectedChannel"
        :options="channelOptions"
        :placeholder="t('AUTOMATION.ACTION.INBOX_MESSAGE.CHANNEL_PLACEHOLDER')"
        :dropdown-max-height="dropdownMaxHeight"
        class="self-start"
      />
      <WootMessageEditor
        v-model="message"
        rows="4"
        enable-variables
        :placeholder="t('AUTOMATION.ACTION.INBOX_MESSAGE.MESSAGE_PLACEHOLDER')"
        class="[&_.ProseMirror-menubar]:hidden px-3 py-1 bg-n-alpha-1 rounded-lg outline outline-1 outline-n-weak dark:outline-n-strong"
      />
      <p class="mb-0 text-xs text-n-slate-11">
        {{ t('AUTOMATION.ACTION.INBOX_MESSAGE.HINT') }}
      </p>
    </template>
  </div>
</template>
