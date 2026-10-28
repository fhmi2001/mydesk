<script setup>
// Custom (MyDesk): the assistant's knowledge sources, refreshed while any of them is still being read
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import smartAssistantAPI from 'dashboard/api/integrations/smartAssistant';

import AddSourceDialog from './AddSourceDialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

defineProps({
  canEdit: { type: Boolean, default: true },
});

const emit = defineEmits(['update:count']);

const POLL_INTERVAL = 3000;
const KIND_ICONS = {
  faq: 'i-lucide-message-circle-question',
  text: 'i-lucide-text',
  website: 'i-lucide-globe',
  document: 'i-lucide-file-text',
};
const STATUS_STYLES = {
  pending: 'bg-n-slate-3 text-n-slate-11',
  processing: 'bg-n-amber-3 text-n-amber-11',
  ready: 'bg-n-teal-3 text-n-teal-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
};
const IN_PROGRESS = ['pending', 'processing'];

const { t, locale } = useI18n();

const sources = ref([]);
const isLoading = ref(true);
const hasError = ref(false);
const busyId = ref(null);
const pendingDelete = ref(null);
const addDialogRef = ref(null);
const deleteDialogRef = ref(null);
let pollTimer = null;

const dateFormat = computed(
  () =>
    new Intl.DateTimeFormat(locale.value, {
      dateStyle: 'medium',
      timeStyle: 'short',
    })
);
const formatDate = seconds => dateFormat.value.format(new Date(seconds * 1000));

const isInProgress = computed(() =>
  sources.value.some(source => IN_PROGRESS.includes(source.status))
);

const schedulePoll = () => {
  clearTimeout(pollTimer);
  // eslint-disable-next-line no-use-before-define
  if (isInProgress.value) pollTimer = setTimeout(fetchSources, POLL_INTERVAL);
};

const setSources = list => {
  sources.value = list;
  emit('update:count', list.filter(source => source.status === 'ready').length);
  schedulePoll();
};

const fetchSources = async () => {
  try {
    const { data } = await smartAssistantAPI.sources();
    setSources(data.payload);
    hasError.value = false;
  } catch {
    hasError.value = true;
  } finally {
    isLoading.value = false;
  }
};

const onCreated = source => setSources([source, ...sources.value]);

const sync = async source => {
  busyId.value = source.id;
  try {
    const { data } = await smartAssistantAPI.syncSource(source.id);
    setSources(sources.value.map(item => (item.id === data.id ? data : item)));
  } catch (error) {
    useAlert(
      error.response?.data?.message || t('SMART_ASSISTANT.KNOWLEDGE.ERROR')
    );
  } finally {
    busyId.value = null;
  }
};

const askDelete = source => {
  pendingDelete.value = source;
  deleteDialogRef.value?.open();
};

const confirmDelete = async () => {
  const source = pendingDelete.value;
  deleteDialogRef.value?.close();
  busyId.value = source.id;
  try {
    await smartAssistantAPI.deleteSource(source.id);
    setSources(sources.value.filter(item => item.id !== source.id));
    useAlert(t('SMART_ASSISTANT.KNOWLEDGE.DELETED'));
  } catch {
    useAlert(t('SMART_ASSISTANT.KNOWLEDGE.ERROR'));
  } finally {
    busyId.value = null;
  }
};

const detailFor = source => {
  if (source.status === 'failed') return source.error_message;
  if (source.status !== 'ready') return '';
  return [
    t('SMART_ASSISTANT.KNOWLEDGE.PASSAGES', { count: source.chunks_count }),
    source.synced_at &&
      t('SMART_ASSISTANT.KNOWLEDGE.UPDATED', {
        time: formatDate(source.synced_at),
      }),
  ]
    .filter(Boolean)
    .join(' · ');
};

onMounted(fetchSources);
onBeforeUnmount(() => clearTimeout(pollTimer));
</script>

<template>
  <section class="flex flex-col gap-4">
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div class="flex flex-col flex-1 gap-1 min-w-64">
        <h2 class="text-heading-2 text-n-slate-12">
          {{ t('SMART_ASSISTANT.KNOWLEDGE.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{ t('SMART_ASSISTANT.KNOWLEDGE.HINT') }}
        </p>
      </div>
      <Button
        icon="i-lucide-plus"
        :label="t('SMART_ASSISTANT.KNOWLEDGE.ADD')"
        :disabled="!canEdit"
        @click="addDialogRef?.open()"
      />
    </div>

    <div
      v-if="isLoading"
      class="flex items-center justify-center py-12 text-n-slate-11"
    >
      <Spinner />
    </div>

    <p
      v-else-if="hasError"
      role="alert"
      class="px-4 py-3 text-sm rounded-xl bg-n-ruby-3 text-n-ruby-11"
    >
      {{ t('SMART_ASSISTANT.KNOWLEDGE.ERROR') }}
    </p>

    <div
      v-else-if="!sources.length"
      class="flex flex-col items-center gap-2 px-6 py-12 text-center rounded-xl outline outline-1 -outline-offset-1 outline-dashed outline-n-strong"
    >
      <span
        class="grid rounded-xl size-11 place-items-center bg-n-blue-3 text-n-blue-11"
      >
        <span class="i-lucide-book-open size-5" aria-hidden="true" />
      </span>
      <h3 class="text-sm font-medium text-n-slate-12">
        {{ t('SMART_ASSISTANT.KNOWLEDGE.EMPTY_TITLE') }}
      </h3>
      <p class="max-w-sm text-sm text-n-slate-11">
        {{ t('SMART_ASSISTANT.KNOWLEDGE.EMPTY_HINT') }}
      </p>
    </div>

    <ul
      v-else
      class="flex flex-col overflow-hidden divide-y rounded-xl outline outline-1 -outline-offset-1 outline-n-weak divide-n-weak"
    >
      <li
        v-for="source in sources"
        :key="source.id"
        class="flex flex-wrap items-center gap-3 px-4 py-3 bg-n-card"
      >
        <span
          class="grid rounded-lg size-9 shrink-0 place-items-center bg-n-alpha-2 text-n-slate-11"
          :title="t(`SMART_ASSISTANT.KNOWLEDGE.KINDS.${source.kind}`)"
        >
          <span
            :class="KIND_ICONS[source.kind]"
            class="size-4"
            aria-hidden="true"
          />
        </span>
        <div class="flex flex-col flex-1 gap-0.5 min-w-48">
          <span
            class="text-sm font-medium truncate text-n-slate-12"
            :dir="source.kind === 'website' ? 'ltr' : undefined"
            :class="{ 'text-start': source.kind === 'website' }"
          >
            {{ source.title }}
          </span>
          <span
            v-if="detailFor(source)"
            class="text-xs truncate"
            :class="
              source.status === 'failed' ? 'text-n-ruby-11' : 'text-n-slate-11'
            "
          >
            {{ detailFor(source) }}
          </span>
        </div>
        <span
          class="inline-flex items-center gap-1 h-5 px-2 text-xs font-medium rounded-full whitespace-nowrap"
          :class="STATUS_STYLES[source.status]"
        >
          <span
            v-if="source.status === 'processing'"
            class="i-lucide-loader-circle size-3 animate-spin motion-reduce:animate-none"
            aria-hidden="true"
          />
          {{ t(`SMART_ASSISTANT.KNOWLEDGE.STATUS.${source.status}`) }}
        </span>
        <div class="flex items-center gap-1">
          <Button
            v-if="source.kind === 'website' || source.status === 'failed'"
            variant="ghost"
            color="slate"
            size="sm"
            icon="i-lucide-refresh-cw"
            :title="t('SMART_ASSISTANT.KNOWLEDGE.SYNC')"
            :aria-label="t('SMART_ASSISTANT.KNOWLEDGE.SYNC')"
            :is-loading="busyId === source.id"
            :disabled="!canEdit || source.status === 'processing'"
            @click="sync(source)"
          />
          <Button
            variant="ghost"
            color="ruby"
            size="sm"
            icon="i-lucide-trash-2"
            :title="t('SMART_ASSISTANT.KNOWLEDGE.DELETE')"
            :aria-label="t('SMART_ASSISTANT.KNOWLEDGE.DELETE')"
            :disabled="busyId === source.id"
            @click="askDelete(source)"
          />
        </div>
      </li>
    </ul>

    <AddSourceDialog ref="addDialogRef" @created="onCreated" />
    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="t('SMART_ASSISTANT.KNOWLEDGE.DELETE_CONFIRM.TITLE')"
      :description="
        t('SMART_ASSISTANT.KNOWLEDGE.DELETE_CONFIRM.MESSAGE', {
          title: pendingDelete?.title,
        })
      "
      :confirm-button-label="
        t('SMART_ASSISTANT.KNOWLEDGE.DELETE_CONFIRM.CONFIRM')
      "
      @confirm="confirmDelete"
    />
  </section>
</template>
