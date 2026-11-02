<script setup>
// Custom (MyDesk): the smart assistant saw a clear intent to buy in this conversation (CONVERSATION_SALES_PLAN.md, أ2).
// Nothing is created until the employee chooses: «إنشاء صفقة» opens the deal form filled from it, «تجاهل» dismisses it.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  suggestion: { type: Object, required: true },
});
const emit = defineEmits(['create', 'dismiss']);
const { t } = useI18n();

const content = computed(() => props.suggestion.content || {});
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
    class="flex flex-col gap-2 p-3 rounded-lg bg-n-iris-2 outline outline-1 -outline-offset-1 outline-n-iris-5"
    :aria-label="t('CRM.PANEL.SUGGESTION.TITLE')"
  >
    <p
      class="flex items-center gap-1.5 text-label-small font-medium text-n-iris-11"
    >
      <span class="i-lucide-sparkles size-3.5" aria-hidden="true" />
      {{ t('CRM.PANEL.SUGGESTION.TITLE') }}
    </p>
    <p v-if="content.summary" class="text-body-main text-n-slate-12" dir="auto">
      {{ content.summary }}
    </p>
    <p
      v-if="details"
      data-testid="suggestion-details"
      class="text-label-small text-n-slate-11"
      dir="auto"
    >
      {{ details }}
    </p>
    <div class="flex items-center gap-2">
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
