<script setup>
// Custom (MyDesk): the smart assistant saw a clear intent to buy in this conversation (CONVERSATION_SALES_PLAN.md, أ2).
// Nothing is created until the employee chooses: «إنشاء صفقة» opens the deal form filled from it, «تجاهل» dismisses it.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  suggestion: { type: Object, required: true },
  // One short row (above the reply box): the text beside its buttons, wrapping on a narrow screen
  inline: { type: Boolean, default: false },
});
const emit = defineEmits(['create', 'dismiss']);
const { t } = useI18n();

const content = computed(() => props.suggestion.content || {});
const heading = computed(() =>
  props.suggestion.origin === 'automation'
    ? t('CRM.PANEL.SUGGESTION.FROM_AUTOMATION')
    : t('CRM.PANEL.SUGGESTION.TITLE')
);
// What, how many, where: only the parts the customer said
const details = computed(() =>
  [content.value.product, content.value.quantity, content.value.city]
    .map(part => String(part || '').trim())
    .filter(Boolean)
    .join(' · ')
);
</script>

<template>
  <section
    class="flex gap-2 p-3 rounded-lg bg-n-iris-2 outline outline-1 -outline-offset-1 outline-n-iris-5"
    :class="inline ? 'flex-wrap items-center justify-between' : 'flex-col'"
    :aria-label="heading"
  >
    <div class="flex flex-col min-w-0 gap-1" :class="{ 'flex-1': inline }">
      <p
        class="flex items-center gap-1.5 text-label-small font-medium text-n-iris-11"
      >
        <span class="i-lucide-sparkles size-3.5" aria-hidden="true" />
        {{ heading }}
      </p>
      <!-- The assistant writes a summary; an automation rule gives a title -->
      <p
        v-if="content.summary || content.title"
        class="text-body-main text-n-slate-12"
        dir="auto"
      >
        {{ content.summary || content.title }}
      </p>
      <p
        v-if="details"
        data-testid="suggestion-details"
        class="text-label-small text-n-slate-11"
        dir="auto"
      >
        {{ details }}
      </p>
    </div>
    <div class="flex items-center gap-2 shrink-0">
      <Button
        :label="t('CRM.PANEL.SUGGESTION.CREATE')"
        size="xs"
        icon="i-lucide-briefcase"
        @click="emit('create', suggestion)"
      />
      <Button
        :label="t('CRM.PANEL.SUGGESTION.DISMISS')"
        size="xs"
        variant="ghost"
        color="slate"
        @click="emit('dismiss', suggestion)"
      />
    </div>
  </section>
</template>
