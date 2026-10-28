<script setup>
// Custom (MyDesk): add one knowledge source: a question and answer, free text, a web page or a document
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import smartAssistantAPI from 'dashboard/api/integrations/smartAssistant';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['created']);

const KINDS = [
  { value: 'faq', icon: 'i-lucide-message-circle-question' },
  { value: 'text', icon: 'i-lucide-text' },
  { value: 'website', icon: 'i-lucide-globe' },
  { value: 'document', icon: 'i-lucide-file-text' },
];
const ACCEPTED_FILES = '.pdf,.txt,.md,.csv';
const MAX_TEXT_LENGTH = 100000;
const MAX_ANSWER_LENGTH = 4000;

const { t } = useI18n();

const dialogRef = ref(null);
const fileInputRef = ref(null);
const kind = ref('faq');
const title = ref('');
const content = ref('');
const url = ref('');
const file = ref(null);
const isSaving = ref(false);

const isValid = computed(() => {
  if (kind.value === 'faq' || kind.value === 'text')
    return !!title.value.trim() && !!content.value.trim();
  if (kind.value === 'website') return /^https?:\/\/\S+$/i.test(url.value);
  return !!file.value;
});

const reset = () => {
  kind.value = 'faq';
  title.value = '';
  content.value = '';
  url.value = '';
  file.value = null;
};

const open = () => {
  reset();
  dialogRef.value?.open();
};

const onFileChange = event => {
  [file.value] = event.target.files;
};

const save = async () => {
  if (!isValid.value) return;
  const formData = new FormData();
  formData.append('kind', kind.value);
  if (kind.value === 'faq' || kind.value === 'text') {
    formData.append('title', title.value.trim());
    formData.append('content', content.value.trim());
  } else if (kind.value === 'website') {
    formData.append('url', url.value.trim());
  } else {
    formData.append('file', file.value);
  }

  isSaving.value = true;
  try {
    const { data } = await smartAssistantAPI.createSource(formData);
    emit('created', data);
    useAlert(t('SMART_ASSISTANT.ADD_SOURCE.ADDED'));
    dialogRef.value?.close();
  } catch (error) {
    useAlert(
      error.response?.data?.message || t('SMART_ASSISTANT.ADD_SOURCE.ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="xl"
    :title="t('SMART_ASSISTANT.ADD_SOURCE.TITLE')"
    :confirm-button-label="t('SMART_ASSISTANT.ADD_SOURCE.SAVE')"
    :cancel-button-label="t('SMART_ASSISTANT.ADD_SOURCE.CANCEL')"
    :disable-confirm-button="!isValid"
    :is-loading="isSaving"
    @confirm="save"
  >
    <div class="flex flex-col gap-5">
      <div
        role="radiogroup"
        :aria-label="t('SMART_ASSISTANT.ADD_SOURCE.TITLE')"
        class="grid grid-cols-2 gap-2 sm:grid-cols-4"
      >
        <button
          v-for="option in KINDS"
          :key="option.value"
          type="button"
          role="radio"
          :aria-checked="kind === option.value"
          class="flex flex-col items-center gap-1.5 px-2 py-3 text-sm rounded-xl outline outline-1 -outline-offset-1 transition-colors touch:min-h-11"
          :class="
            kind === option.value
              ? 'bg-n-blue-3 outline-n-blue-6 text-n-blue-11 font-medium'
              : 'outline-n-weak text-n-slate-12 hover:bg-n-alpha-2'
          "
          @click="kind = option.value"
        >
          <span :class="option.icon" class="size-5" aria-hidden="true" />
          {{ t(`SMART_ASSISTANT.KNOWLEDGE.KINDS.${option.value}`) }}
        </button>
      </div>

      <template v-if="kind === 'faq'">
        <Input
          v-model="title"
          :label="t('SMART_ASSISTANT.ADD_SOURCE.QUESTION')"
          :placeholder="t('SMART_ASSISTANT.ADD_SOURCE.QUESTION_PLACEHOLDER')"
          autofocus
        />
        <TextArea
          v-model="content"
          :label="t('SMART_ASSISTANT.ADD_SOURCE.ANSWER')"
          :placeholder="t('SMART_ASSISTANT.ADD_SOURCE.ANSWER_PLACEHOLDER')"
          :max-length="MAX_ANSWER_LENGTH"
          auto-height
          min-height="6rem"
        />
      </template>

      <template v-else-if="kind === 'text'">
        <Input
          v-model="title"
          :label="t('SMART_ASSISTANT.ADD_SOURCE.TEXT_TITLE')"
          :placeholder="t('SMART_ASSISTANT.ADD_SOURCE.TEXT_TITLE_PLACEHOLDER')"
          autofocus
        />
        <TextArea
          v-model="content"
          :label="t('SMART_ASSISTANT.ADD_SOURCE.TEXT')"
          :placeholder="t('SMART_ASSISTANT.ADD_SOURCE.TEXT_PLACEHOLDER')"
          :max-length="MAX_TEXT_LENGTH"
          auto-height
          min-height="10rem"
          max-height="20rem"
        />
      </template>

      <Input
        v-else-if="kind === 'website'"
        v-model="url"
        type="url"
        dir="ltr"
        :label="t('SMART_ASSISTANT.ADD_SOURCE.URL')"
        placeholder="https://"
        :message="t('SMART_ASSISTANT.ADD_SOURCE.URL_HINT')"
        autofocus
      />

      <div v-else class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('SMART_ASSISTANT.ADD_SOURCE.FILE') }}
        </span>
        <input
          ref="fileInputRef"
          type="file"
          class="sr-only"
          :accept="ACCEPTED_FILES"
          @change="onFileChange"
        />
        <div
          class="flex flex-wrap items-center gap-3 px-4 py-3 rounded-xl outline outline-1 -outline-offset-1 outline-dashed outline-n-strong"
        >
          <Button
            type="button"
            variant="faded"
            color="slate"
            size="sm"
            icon="i-lucide-upload"
            :label="t('SMART_ASSISTANT.ADD_SOURCE.CHOOSE_FILE')"
            @click="fileInputRef?.click()"
          />
          <span
            class="flex-1 min-w-0 text-sm truncate"
            :class="file ? 'text-n-slate-12' : 'text-n-slate-11'"
          >
            {{ file ? file.name : t('SMART_ASSISTANT.ADD_SOURCE.FILE_HINT') }}
          </span>
        </div>
      </div>
    </div>
  </Dialog>
</template>
