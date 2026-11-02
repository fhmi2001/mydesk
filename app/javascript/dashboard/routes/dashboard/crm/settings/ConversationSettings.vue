<script setup>
// Custom (MyDesk): Sales > Settings > Conversations (CONVERSATION_SALES_PLAN.md): the lead source a deal starts with
// for each inbox (kept per inbox, since WhatsApp Web shares its channel type with every API inbox), the silent days
// before a follow-up, and the window in which an SMS campaign counts toward a new deal. Emits one `save` patch per change.
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Select from 'dashboard/components-next/select/Select.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  inboxes: { type: Array, required: true },
  sources: { type: Array, required: true },
  settings: { type: Object, required: true },
});
const emit = defineEmits(['save']);
const { t } = useI18n();

const sourceOptions = computed(() => [
  { value: '', label: t('CRM.SETTINGS.CONVERSATIONS.NO_SOURCE') },
  ...props.sources.map(item => ({ value: String(item.id), label: item.name })),
]);
const sourceOf = inbox =>
  String(props.settings.channel_sources?.[inbox.id] ?? '');
const pickSource = (inbox, value) =>
  emit('save', {
    channel_sources: { [inbox.id]: value ? Number(value) : null },
  });

// Typed, then saved when the field is left with a new value
const followupDays = ref('');
const smsDays = ref('');
watch(
  () => props.settings,
  settings => {
    followupDays.value = String(settings.followup_days ?? '');
    smsDays.value = String(settings.sms_attribution_days ?? '');
  },
  { immediate: true }
);
const saveDays = (key, value) => {
  if (String(value).trim() === String(props.settings[key])) return;
  emit('save', { [key]: value });
};
</script>

<template>
  <section
    class="flex flex-col gap-6 p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
    aria-labelledby="crm-settings-conversations"
  >
    <h2 id="crm-settings-conversations" class="sr-only">
      {{ t('CRM.SETTINGS.TABS.conversations') }}
    </h2>

    <div>
      <h3 class="mb-1 text-heading-3 text-n-slate-12">
        {{ t('CRM.SETTINGS.CONVERSATIONS.SOURCES_HEADING') }}
      </h3>
      <p class="mb-3 text-label-small text-n-slate-11">
        {{ t('CRM.SETTINGS.CONVERSATIONS.SOURCES_HINT') }}
      </p>
      <p v-if="!inboxes.length" class="text-body-main text-n-slate-11">
        {{ t('CRM.SETTINGS.CONVERSATIONS.NO_INBOXES') }}
      </p>
      <ul v-else class="flex flex-col divide-y divide-n-weak">
        <li
          v-for="inbox in inboxes"
          :key="inbox.id"
          class="flex flex-wrap items-center justify-between gap-3 py-2"
        >
          <span class="min-w-0 truncate text-body-main text-n-slate-12">
            {{ inbox.name }}
          </span>
          <Select
            :model-value="sourceOf(inbox)"
            :options="sourceOptions"
            :aria-label="
              t('CRM.SETTINGS.CONVERSATIONS.SOURCE_FOR', { inbox: inbox.name })
            "
            class="shrink-0"
            @update:model-value="value => pickSource(inbox, value)"
          />
        </li>
      </ul>
    </div>

    <div>
      <h3 class="mb-1 text-heading-3 text-n-slate-12">
        {{ t('CRM.SETTINGS.CONVERSATIONS.FOLLOWUP_HEADING') }}
      </h3>
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Input
          v-model="followupDays"
          inputmode="numeric"
          :label="t('CRM.SETTINGS.CONVERSATIONS.FOLLOWUP_DAYS')"
          :message="t('CRM.SETTINGS.CONVERSATIONS.FOLLOWUP_DAYS_HINT')"
          @blur="saveDays('followup_days', followupDays)"
        />
        <Input
          v-model="smsDays"
          inputmode="numeric"
          :label="t('CRM.SETTINGS.CONVERSATIONS.SMS_DAYS')"
          :message="t('CRM.SETTINGS.CONVERSATIONS.SMS_DAYS_HINT')"
          @blur="saveDays('sms_attribution_days', smsDays)"
        />
      </div>
      <label
        class="flex items-start gap-2 mt-4 cursor-pointer text-body-main text-n-slate-12"
      >
        <input
          type="checkbox"
          data-testid="won-lost-messages"
          class="mt-1 size-4 accent-n-brand"
          :checked="settings.won_lost_messages !== false"
          @change="
            event => emit('save', { won_lost_messages: event.target.checked })
          "
        />
        <span>
          {{ t('CRM.SETTINGS.CONVERSATIONS.WON_LOST') }}
          <span class="block text-label-small text-n-slate-11">
            {{ t('CRM.SETTINGS.CONVERSATIONS.WON_LOST_HINT') }}
          </span>
        </span>
      </label>
    </div>
  </section>
</template>
