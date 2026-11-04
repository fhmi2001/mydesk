<script setup>
// Custom (MyDesk): a deal's follow-up, thank-you or "why not?" suggestion in its conversation
// (CONVERSATION_SALES_PLAN.md). The draft is written only on request; the employee edits it, copies it and sends it themselves, so nothing
// reaches the customer from here. Official WhatsApp past its 24 hours takes templates only, which the card says.
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const props = defineProps({
  suggestion: { type: Object, required: true },
  canReply: { type: Boolean, default: true },
  csatSurveyEnabled: { type: Boolean, default: false },
  isWriting: { type: Boolean, default: false },
});
const emit = defineEmits(['write', 'copy', 'dismiss']);
const { t } = useI18n();

const text = ref('');
watch(
  () => props.suggestion.content?.draft,
  draft => {
    text.value = draft || '';
  },
  { immediate: true }
);

const TITLES = {
  follow_up: () => t('CRM.PANEL.DEAL_MESSAGE.follow_up'),
  won_message: () => t('CRM.PANEL.DEAL_MESSAGE.won_message'),
  lost_question: () => t('CRM.PANEL.DEAL_MESSAGE.lost_question'),
};
</script>

<template>
  <section
    class="flex flex-col gap-2 p-3 rounded-lg bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
    :aria-label="TITLES[suggestion.kind]?.()"
  >
    <p class="text-label-small font-medium text-n-slate-11">
      {{ TITLES[suggestion.kind]?.() }}
      <span class="text-n-slate-12" dir="auto">{{
        `· ${suggestion.deal_title || ''}`
      }}</span>
    </p>

    <TextArea
      v-if="suggestion.content?.draft"
      v-model="text"
      :label="t('CRM.PANEL.DEAL_MESSAGE.DRAFT')"
      auto-height
      class="w-full"
    />
    <p
      v-if="suggestion.content?.draft && !canReply"
      class="text-label-small text-n-amber-11"
    >
      {{ t('CRM.PANEL.DEAL_MESSAGE.WINDOW_CLOSED') }}
    </p>
    <p
      v-if="suggestion.kind === 'won_message' && csatSurveyEnabled"
      class="text-label-small text-n-slate-11"
    >
      {{ t('CRM.PANEL.DEAL_MESSAGE.CSAT_HINT') }}
    </p>

    <div class="flex flex-wrap items-center gap-2">
      <Button
        v-if="!suggestion.content?.draft"
        data-testid="write-draft"
        :label="t('CRM.PANEL.DEAL_MESSAGE.WRITE')"
        size="xs"
        variant="faded"
        icon="i-lucide-sparkles"
        :is-loading="isWriting"
        :disabled="isWriting"
        @click="emit('write', suggestion)"
      />
      <Button
        v-else
        data-testid="copy-draft"
        :label="t('CRM.PANEL.DEAL_MESSAGE.COPY')"
        size="xs"
        icon="i-lucide-copy"
        :disabled="!text.trim()"
        @click="emit('copy', suggestion, text.trim())"
      />
      <Button
        data-testid="dismiss"
        :label="t('CRM.PANEL.DEAL_MESSAGE.DISMISS')"
        size="xs"
        variant="ghost"
        color="slate"
        @click="emit('dismiss', suggestion)"
      />
    </div>
  </section>
</template>
