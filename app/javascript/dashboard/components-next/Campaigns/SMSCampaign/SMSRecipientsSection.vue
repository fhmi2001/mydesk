<script setup>
// Custom (MyDesk): where an SMS campaign's numbers come from — contact labels, typed numbers or an Excel/CSV file.
// Every change is checked by the server, which cleans the numbers and reports valid, duplicate and rejected ones.
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { debounce } from '@chatwoot/utils';

import CampaignsAPI from 'dashboard/api/campaigns';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  labels: { type: Array, default: () => [] },
});

const source = defineModel('source', { type: String, required: true });
const labelIds = defineModel('labelIds', { type: Array, default: () => [] });
const numbersText = defineModel('numbersText', { type: String, default: '' });
const file = defineModel('file', { type: Object, default: null });
const preview = defineModel('preview', { type: Object, default: null });

const SOURCES = [
  { id: 'labels', icon: 'i-lucide-tags' },
  { id: 'manual', icon: 'i-lucide-keyboard' },
  { id: 'file', icon: 'i-lucide-file-spreadsheet' },
];
const TYPING_DELAY_MS = 600;
const MAX_TYPED_LENGTH = 200000;
const ACCEPTED_FILES = '.xlsx,.csv';
const SAMPLE_FILE_ROWS = ['رقم الجوال', '0551234567', '966551234568'];
// Lets Excel open the sample CSV as UTF-8 so the Arabic header shows correctly
const UTF8_BOM = String.fromCharCode(0xfeff);

const { t } = useI18n();
const { run, isPending } = useAbortableRequest();
const error = ref('');

const sourceLabels = computed(() => ({
  labels: t('CAMPAIGN.SMS.RECIPIENTS.SOURCES.LABELS'),
  manual: t('CAMPAIGN.SMS.RECIPIENTS.SOURCES.MANUAL'),
  file: t('CAMPAIGN.SMS.RECIPIENTS.SOURCES.FILE'),
}));
const errorMessages = computed(() => ({
  unsupported_format: t('CAMPAIGN.SMS.RECIPIENTS.ERRORS.UNSUPPORTED_FORMAT'),
  file_too_large: t('CAMPAIGN.SMS.RECIPIENTS.ERRORS.FILE_TOO_LARGE'),
  unreadable: t('CAMPAIGN.SMS.RECIPIENTS.ERRORS.UNREADABLE'),
}));

const labelOptions = computed(() =>
  props.labels.map(label => ({ value: label.id, label: label.title }))
);

const requestBySource = () => {
  if (source.value === 'labels' && labelIds.value.length)
    return { labelIds: labelIds.value };
  if (source.value === 'manual' && numbersText.value.trim())
    return { numbers: numbersText.value };
  if (source.value === 'file' && file.value) return { file: file.value };
  return null;
};

const checkNumbers = async () => {
  error.value = '';
  const request = requestBySource();
  if (!request) {
    preview.value = null;
    return;
  }
  try {
    const response = await run(signal =>
      CampaignsAPI.previewSmsRecipients(request, { signal })
    );
    if (response) preview.value = response.data;
  } catch (requestError) {
    preview.value = null;
    error.value =
      errorMessages.value[requestError?.response?.data?.error] ||
      t('CAMPAIGN.SMS.RECIPIENTS.ERRORS.GENERIC');
  }
};
const checkTypedNumbers = debounce(checkNumbers, TYPING_DELAY_MS);

watch(source, checkNumbers);
watch(labelIds, checkNumbers, { deep: true });
watch(numbersText, checkTypedNumbers);
watch(file, checkNumbers);

const onFileChange = event => {
  [file.value] = event.target.files;
  event.target.value = '';
};
const removeFile = () => {
  file.value = null;
};

const downloadSample = () => {
  const blob = new Blob([`${UTF8_BOM}${SAMPLE_FILE_ROWS.join('\n')}\n`], {
    type: 'text/csv;charset=utf-8',
  });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = 'sms-numbers-sample.csv';
  link.click();
  URL.revokeObjectURL(link.href);
};

const isLabelSource = computed(() => source.value === 'labels');
const invalidSamples = computed(() =>
  (preview.value?.invalid_samples ?? []).join(', ')
);
const summary = computed(() => {
  if (!preview.value) return [];
  if (isLabelSource.value) {
    return [
      {
        key: 'contacts',
        tone: 'text-n-teal-11',
        value: preview.value.label_recipients_count,
        label: t('CAMPAIGN.SMS.RECIPIENTS.SUMMARY.LABEL_CONTACTS'),
      },
    ];
  }
  return [
    {
      key: 'valid',
      tone: 'text-n-teal-11',
      value: preview.value.valid_count,
      label: t('CAMPAIGN.SMS.RECIPIENTS.SUMMARY.VALID'),
    },
    {
      key: 'duplicates',
      tone: 'text-n-amber-11',
      value: preview.value.duplicate_count,
      label: t('CAMPAIGN.SMS.RECIPIENTS.SUMMARY.DUPLICATES'),
    },
    {
      key: 'invalid',
      tone: 'text-n-ruby-11',
      value: preview.value.invalid_count,
      label: t('CAMPAIGN.SMS.RECIPIENTS.SUMMARY.INVALID'),
    },
    {
      key: 'code',
      tone: 'text-n-slate-12',
      value: preview.value.country_code_added_count,
      label: t('CAMPAIGN.SMS.RECIPIENTS.SUMMARY.CODE_ADDED'),
    },
  ];
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <div
      class="grid grid-cols-3 gap-1 p-1 rounded-xl bg-n-alpha-2"
      role="tablist"
    >
      <button
        v-for="item in SOURCES"
        :key="item.id"
        type="button"
        role="tab"
        :aria-selected="source === item.id"
        class="flex items-center justify-center gap-2 px-3 py-2 text-sm rounded-lg transition-colors"
        :class="
          source === item.id
            ? 'bg-n-solid-1 text-n-slate-12 shadow-sm font-medium'
            : 'text-n-slate-11 hover:text-n-slate-12'
        "
        @click="source = item.id"
      >
        <span class="size-4" :class="item.icon" />
        {{ sourceLabels[item.id] }}
      </button>
    </div>

    <TagMultiSelectComboBox
      v-if="source === 'labels'"
      v-model="labelIds"
      :options="labelOptions"
      :label="t('CAMPAIGN.SMS.CREATE.FORM.AUDIENCE.LABEL')"
      :placeholder="t('CAMPAIGN.SMS.CREATE.FORM.AUDIENCE.PLACEHOLDER')"
      class="[&>div>button]:bg-n-alpha-black2"
    />

    <TextArea
      v-else-if="source === 'manual'"
      v-model="numbersText"
      :label="t('CAMPAIGN.SMS.RECIPIENTS.MANUAL.LABEL')"
      :placeholder="t('CAMPAIGN.SMS.RECIPIENTS.MANUAL.PLACEHOLDER')"
      :message="t('CAMPAIGN.SMS.RECIPIENTS.MANUAL.HELP')"
      :max-length="MAX_TYPED_LENGTH"
      min-height="8rem"
      dir="ltr"
    />

    <div v-else class="flex flex-col gap-2">
      <label
        v-if="!file"
        class="flex flex-col items-center justify-center gap-2 px-4 py-8 text-center border border-dashed cursor-pointer rounded-xl border-n-strong hover:bg-n-alpha-1"
      >
        <span class="size-8 text-n-slate-10 i-lucide-file-up" />
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CAMPAIGN.SMS.RECIPIENTS.FILE.CHOOSE') }}
        </span>
        <span class="text-xs text-n-slate-11">
          {{ t('CAMPAIGN.SMS.RECIPIENTS.FILE.HELP') }}
        </span>
        <input
          type="file"
          class="sr-only"
          :accept="ACCEPTED_FILES"
          @change="onFileChange"
        />
      </label>
      <div
        v-else
        class="flex items-center justify-between gap-3 px-4 py-3 rounded-xl bg-n-alpha-2"
      >
        <div class="flex items-center min-w-0 gap-2">
          <span class="size-5 text-n-teal-11 i-lucide-file-spreadsheet" />
          <span class="text-sm truncate text-n-slate-12">{{ file.name }}</span>
        </div>
        <Button
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-x"
          :aria-label="t('CAMPAIGN.SMS.RECIPIENTS.FILE.REMOVE')"
          @click="removeFile"
        />
      </div>
      <button
        type="button"
        class="self-start text-xs text-n-blue-11 hover:underline"
        @click="downloadSample"
      >
        {{ t('CAMPAIGN.SMS.RECIPIENTS.FILE.SAMPLE') }}
      </button>
    </div>

    <div
      v-if="isPending"
      class="flex items-center gap-2 text-sm text-n-slate-11"
    >
      <Spinner class="size-4" />
      {{ t('CAMPAIGN.SMS.RECIPIENTS.CHECKING') }}
    </div>
    <p v-else-if="error" class="text-sm text-n-ruby-11">{{ error }}</p>
    <template v-else-if="preview">
      <dl
        class="grid gap-2"
        :class="isLabelSource ? 'grid-cols-1' : 'grid-cols-2 sm:grid-cols-4'"
      >
        <div
          v-for="item in summary"
          :key="item.key"
          class="flex flex-col gap-0.5 px-3 py-2 rounded-lg bg-n-alpha-1"
        >
          <dt class="text-xs text-n-slate-11">{{ item.label }}</dt>
          <dd class="text-lg font-semibold tabular-nums" :class="item.tone">
            {{ item.value }}
          </dd>
        </div>
      </dl>
      <details
        v-if="!isLabelSource && preview.invalid_samples.length"
        class="text-sm text-n-slate-11"
      >
        <summary class="cursor-pointer">
          {{ t('CAMPAIGN.SMS.RECIPIENTS.SUMMARY.SHOW_INVALID') }}
        </summary>
        <p dir="ltr" class="mt-2 break-words">
          {{ invalidSamples }}
        </p>
      </details>
    </template>
  </div>
</template>
