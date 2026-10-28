<script setup>
// Custom (MyDesk): Settings > Integrations > Smart Assistant. The merchant turns the assistant on, feeds its
// knowledge base, shapes how it replies, picks the channels it answers on, and tries it out.
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import smartAssistantAPI from 'dashboard/api/integrations/smartAssistant';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import KnowledgeBase from './smartAssistant/KnowledgeBase.vue';
import BehaviorSettings from './smartAssistant/BehaviorSettings.vue';
import ChannelSettings from './smartAssistant/ChannelSettings.vue';
import TestChat from './smartAssistant/TestChat.vue';

const TABS = ['KNOWLEDGE', 'BEHAVIOR', 'CHANNELS', 'TEST'];
const SECTION_CLASSES =
  'flex flex-col gap-5 p-6 rounded-xl outline outline-1 -outline-offset-1 outline-n-weak bg-n-card';

const { t, locale } = useI18n();
const store = useStore();

const isLoaded = ref(false);
const isSaving = ref(false);
const configured = ref(false);
const assistant = ref(null);
const usage = ref(null);
const readySources = ref(null);
const activeTab = ref(0);

const tabs = computed(() =>
  TABS.map(key => ({ key, label: t(`SMART_ASSISTANT.TABS.${key}`) }))
);

const numberFormat = computed(() => new Intl.NumberFormat(locale.value));
const formatNumber = value => numberFormat.value.format(value);

const stats = computed(() => [
  {
    key: 'replies',
    label: t('SMART_ASSISTANT.USAGE.REPLIES'),
    value: formatNumber(usage.value.replies_this_month),
    detail: t('SMART_ASSISTANT.USAGE.OF_LIMIT', {
      limit: formatNumber(usage.value.monthly_limit),
    }),
  },
  {
    key: 'conversations',
    label: t('SMART_ASSISTANT.USAGE.CONVERSATIONS'),
    value: formatNumber(usage.value.conversations_this_month),
  },
  {
    key: 'handoffs',
    label: t('SMART_ASSISTANT.USAGE.HANDOFFS'),
    value: formatNumber(usage.value.handoffs_this_month),
  },
]);

const limitReached = computed(
  () => usage.value.replies_this_month >= usage.value.monthly_limit
);

// What still stands between the merchant and a working assistant, most important first
const notice = computed(() => {
  if (!configured.value) return t('SMART_ASSISTANT.HERO.NOT_CONFIGURED');
  if (!assistant.value.enabled) return '';
  if (!assistant.value.inbox_ids.length)
    return t('SMART_ASSISTANT.HERO.NEEDS_INBOX');
  if (readySources.value === 0)
    return t('SMART_ASSISTANT.HERO.NEEDS_KNOWLEDGE');
  if (limitReached.value) return t('SMART_ASSISTANT.USAGE.LIMIT_REACHED');
  return '';
});

const apply = data => {
  configured.value = data.configured;
  assistant.value = data.assistant;
  usage.value = data.usage;
};

const save = async changes => {
  isSaving.value = true;
  try {
    const { data } = await smartAssistantAPI.save(changes);
    apply(data);
    useAlert(t('SMART_ASSISTANT.BEHAVIOR.SAVED'));
    store.dispatch('integrations/get');
  } catch (error) {
    useAlert(
      error.response?.data?.message || t('SMART_ASSISTANT.BEHAVIOR.ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

const isEnabled = computed({
  get: () => assistant.value.enabled,
  set: enabled => save({ enabled }),
});

onMounted(async () => {
  const [{ data }] = await Promise.all([
    smartAssistantAPI.show(),
    store.dispatch('inboxes/get'),
  ]);
  apply(data);
  isLoaded.value = true;
});
</script>

<template>
  <SettingsLayout :is-loading="!isLoaded">
    <template #header>
      <BaseSettingsHeader
        :title="t('SMART_ASSISTANT.HEADER')"
        description=""
        :back-button-label="t('SMART_ASSISTANT.BACK')"
      />
    </template>
    <template #body>
      <div class="flex flex-col gap-6">
        <section :class="SECTION_CLASSES">
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="flex items-start flex-1 gap-4 min-w-64">
              <span
                class="grid rounded-xl size-12 shrink-0 place-items-center bg-n-blue-3 text-n-blue-11"
              >
                <span class="i-lucide-sparkles size-6" aria-hidden="true" />
              </span>
              <div class="flex flex-col gap-1">
                <h2 class="text-heading-2 text-n-slate-12">
                  {{ t('SMART_ASSISTANT.HERO.TITLE') }}
                </h2>
                <p class="max-w-2xl text-sm text-n-slate-11">
                  {{ t('SMART_ASSISTANT.HERO.DESCRIPTION') }}
                </p>
              </div>
            </div>
            <label
              class="flex items-center gap-3 px-3 py-2 rounded-xl bg-n-alpha-1"
              :class="configured ? 'cursor-pointer' : 'cursor-not-allowed'"
            >
              <span
                class="text-sm font-medium"
                :class="isEnabled ? 'text-n-teal-11' : 'text-n-slate-11'"
              >
                {{
                  isEnabled
                    ? t('SMART_ASSISTANT.HERO.ENABLE')
                    : t('SMART_ASSISTANT.HERO.DISABLED')
                }}
              </span>
              <Switch v-model="isEnabled" :disabled="!configured || isSaving" />
            </label>
          </div>

          <dl
            class="grid grid-cols-1 gap-px overflow-hidden sm:grid-cols-3 rounded-xl bg-n-weak outline outline-1 -outline-offset-1 outline-n-weak"
          >
            <div
              v-for="stat in stats"
              :key="stat.key"
              class="flex flex-col gap-1 px-4 py-3 bg-n-card"
            >
              <dt class="text-xs text-n-slate-11">{{ stat.label }}</dt>
              <dd class="flex items-baseline gap-1.5">
                <span
                  class="text-xl font-semibold tabular-nums text-n-slate-12"
                >
                  {{ stat.value }}
                </span>
                <span v-if="stat.detail" class="text-xs text-n-slate-11">
                  {{ stat.detail }}
                </span>
              </dd>
            </div>
          </dl>

          <p
            v-if="notice"
            role="status"
            class="flex items-start gap-3 px-4 py-3 text-sm rounded-xl bg-n-amber-3 text-n-amber-11"
          >
            <span
              class="i-lucide-info size-4 mt-0.5 shrink-0"
              aria-hidden="true"
            />
            <span>{{ notice }}</span>
          </p>
        </section>

        <div class="overflow-x-auto">
          <TabBar
            :tabs="tabs"
            :initial-active-tab="activeTab"
            @tab-changed="tab => (activeTab = TABS.indexOf(tab.key))"
          />
        </div>

        <div :class="SECTION_CLASSES">
          <KnowledgeBase
            v-show="activeTab === 0"
            :can-edit="configured"
            @update:count="count => (readySources = count)"
          />
          <BehaviorSettings
            v-if="activeTab === 1"
            :assistant="assistant"
            :is-saving="isSaving"
            @save="save"
          />
          <ChannelSettings
            v-else-if="activeTab === 2"
            :assistant="assistant"
            :is-saving="isSaving"
            @save="save"
          />
          <TestChat
            v-show="activeTab === 3"
            :assistant-name="assistant.name"
            :can-test="configured"
          />
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
