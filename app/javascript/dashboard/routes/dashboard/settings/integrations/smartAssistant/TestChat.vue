<script setup>
// Custom (MyDesk): a private chat with the assistant, using the saved settings and knowledge base
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import smartAssistantAPI from 'dashboard/api/integrations/smartAssistant';

import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  assistantName: { type: String, default: '' },
  canTest: { type: Boolean, default: true },
});

const MAX_MESSAGES = 20;
const MAX_LENGTH = 2000;

const { t, locale } = useI18n();

const listFormat = computed(
  () => new Intl.ListFormat(locale.value, { type: 'unit' })
);
const messages = ref([]);
const draft = ref('');
const isWaiting = ref(false);
const hasError = ref(false);
const listRef = ref(null);

const scrollToEnd = async () => {
  await nextTick();
  listRef.value?.scrollTo({ top: listRef.value.scrollHeight });
};

const send = async () => {
  const content = draft.value.trim();
  if (!content || isWaiting.value) return;
  messages.value.push({ role: 'user', content });
  draft.value = '';
  hasError.value = false;
  isWaiting.value = true;
  scrollToEnd();
  try {
    const history = messages.value
      .slice(-MAX_MESSAGES)
      .map(({ role, content: text }) => ({ role, content: text }));
    const { data } = await smartAssistantAPI.test(history);
    messages.value.push({
      role: 'assistant',
      content: data.reply,
      handoff: data.handoff,
      sources: data.sources,
    });
  } catch {
    messages.value.pop();
    draft.value = content;
    hasError.value = true;
  } finally {
    isWaiting.value = false;
    scrollToEnd();
  }
};

const reset = () => {
  messages.value = [];
  hasError.value = false;
};
</script>

<template>
  <section class="flex flex-col gap-4">
    <div class="flex flex-wrap items-start justify-between gap-4">
      <div class="flex flex-col flex-1 gap-1 min-w-64">
        <h2 class="text-heading-2 text-n-slate-12">
          {{ t('SMART_ASSISTANT.TEST.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{ t('SMART_ASSISTANT.TEST.HINT') }}
        </p>
      </div>
      <Button
        v-if="messages.length"
        variant="faded"
        color="slate"
        size="sm"
        icon="i-lucide-rotate-ccw"
        :label="t('SMART_ASSISTANT.TEST.RESET')"
        @click="reset"
      />
    </div>

    <div
      class="flex flex-col overflow-hidden rounded-xl outline outline-1 -outline-offset-1 outline-n-weak bg-n-surface-1"
    >
      <div
        ref="listRef"
        class="flex flex-col gap-3 p-4 overflow-y-auto h-[26rem] max-h-[60vh]"
        aria-live="polite"
      >
        <p
          v-if="!messages.length"
          class="m-auto text-sm text-center text-n-slate-11"
        >
          {{ t('SMART_ASSISTANT.TEST.EMPTY') }}
        </p>
        <div
          v-for="(message, index) in messages"
          :key="index"
          class="flex flex-col gap-1.5 max-w-[85%]"
          :class="message.role === 'user' ? 'self-end items-end' : 'self-start'"
        >
          <span
            v-if="message.role === 'assistant'"
            class="text-xs font-medium text-n-slate-11"
          >
            {{ assistantName }}
          </span>
          <p
            class="px-3 py-2 text-sm whitespace-pre-line rounded-2xl"
            :class="
              message.role === 'user'
                ? 'bg-n-blue-3 text-n-slate-12 rounded-ee-md'
                : 'bg-n-card text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak rounded-es-md'
            "
          >
            {{ message.content }}
          </p>
          <span
            v-if="message.handoff"
            class="inline-flex items-center gap-1 h-5 px-2 text-xs font-medium rounded-full w-fit bg-n-amber-3 text-n-amber-11"
          >
            <span class="i-lucide-user-round size-3" aria-hidden="true" />
            {{ t('SMART_ASSISTANT.TEST.HANDOFF') }}
          </span>
          <span v-if="message.sources?.length" class="text-xs text-n-slate-11">
            {{ t('SMART_ASSISTANT.TEST.SOURCES') }}
            {{ listFormat.format(message.sources.map(source => source.title)) }}
          </span>
        </div>
        <div
          v-if="isWaiting"
          class="flex items-center self-start gap-2 px-3 py-2 text-sm rounded-2xl rounded-es-md bg-n-card text-n-slate-11 outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <span
            class="i-lucide-loader-circle size-4 animate-spin motion-reduce:animate-none"
            aria-hidden="true"
          />
          {{ t('SMART_ASSISTANT.TEST.THINKING') }}
        </div>
      </div>

      <p
        v-if="hasError"
        role="alert"
        class="px-4 py-2 text-sm border-t bg-n-ruby-3 text-n-ruby-11 border-n-weak"
      >
        {{ t('SMART_ASSISTANT.TEST.ERROR') }}
      </p>

      <form
        class="flex items-end gap-2 p-3 border-t border-n-weak bg-n-card"
        @submit.prevent="send"
      >
        <textarea
          v-model="draft"
          rows="1"
          :maxlength="MAX_LENGTH"
          :disabled="!canTest"
          :placeholder="t('SMART_ASSISTANT.TEST.PLACEHOLDER')"
          :aria-label="t('SMART_ASSISTANT.TEST.PLACEHOLDER')"
          class="flex-1 min-h-9 max-h-32 !mb-0 px-3 py-2 text-sm bg-transparent border-0 rounded-lg resize-none field-sizing-content outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-blue-9 text-n-slate-12 placeholder:text-n-slate-10"
          @keydown.enter.exact.prevent="send"
        />
        <Button
          type="submit"
          icon="i-lucide-send-horizontal"
          class="rtl:[&_span]:-scale-x-100"
          :label="t('SMART_ASSISTANT.TEST.SEND')"
          :is-loading="isWaiting"
          :disabled="!canTest || !draft.trim()"
        />
      </form>
    </div>
  </section>
</template>
