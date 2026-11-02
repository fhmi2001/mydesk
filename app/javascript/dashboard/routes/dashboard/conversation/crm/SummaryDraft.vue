<script setup>
// Custom (MyDesk): the conversation summary the assistant drafted (CONVERSATION_SALES_PLAN.md, idea أ3). The employee
// edits the note, then saves it on one of the customer's open deals, or creates a deal from it when there is none.
// The suggested amount and close date reach a deal only through their own button.
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { useCrmFormat } from 'dashboard/routes/dashboard/crm/shared/useCrmFormat';

const props = defineProps({
  draft: { type: Object, required: true },
  deals: { type: Array, default: () => [] },
  isSaving: { type: Boolean, default: false },
});
const emit = defineEmits(['saveNote', 'apply', 'createDeal', 'close']);
const { t } = useI18n();
const { date } = useCrmFormat();

const compose = draft =>
  [
    draft.summary,
    draft.objections &&
      `${t('CRM.PANEL.SUMMARY.OBJECTIONS')}: ${draft.objections}`,
    draft.next_step &&
      `${t('CRM.PANEL.SUMMARY.NEXT_STEP')}: ${draft.next_step}`,
  ]
    .filter(Boolean)
    .join('\n');

const note = ref('');
const dealId = ref('');
watch(
  () => props.draft,
  draft => {
    note.value = compose(draft);
  },
  { immediate: true }
);
watch(
  () => props.deals,
  deals => {
    dealId.value = deals[0] ? String(deals[0].id) : '';
  },
  { immediate: true }
);

const dealOptions = computed(() =>
  props.deals.map(deal => ({ value: String(deal.id), label: deal.title }))
);
const chosenDeal = computed(() =>
  props.deals.find(deal => String(deal.id) === dealId.value)
);
const suggested = computed(() => ({
  amount: props.draft.suggested_amount || null,
  close_date: props.draft.suggested_close_date || null,
}));
const hasSuggested = computed(
  () => suggested.value.amount || suggested.value.close_date
);
const suggestedText = computed(() =>
  [
    suggested.value.amount &&
      t('CRM.PANEL.SUMMARY.AMOUNT', { amount: suggested.value.amount }),
    suggested.value.close_date &&
      t('CRM.PANEL.SUMMARY.CLOSE_DATE', {
        date: date(suggested.value.close_date),
      }),
  ]
    .filter(Boolean)
    .join(' · ')
);

const saveNote = () =>
  emit('saveNote', { deal: chosenDeal.value, content: note.value.trim() });
const apply = () =>
  emit('apply', {
    deal: chosenDeal.value,
    ...Object.fromEntries(
      Object.entries(suggested.value).filter(([, value]) => value)
    ),
  });
const createDeal = () =>
  emit('createDeal', { content: note.value.trim(), ...suggested.value });
</script>

<template>
  <section
    class="flex flex-col gap-2 p-3 rounded-lg bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
    :aria-label="t('CRM.PANEL.SUMMARY.TITLE')"
  >
    <p class="text-label-small font-medium text-n-slate-11">
      {{ t('CRM.PANEL.SUMMARY.TITLE') }}
    </p>
    <TextArea
      v-model="note"
      :label="t('CRM.PANEL.SUMMARY.NOTE')"
      auto-height
      class="w-full"
    />
    <p v-if="hasSuggested" class="text-label-small text-n-slate-11" dir="auto">
      {{ suggestedText }}
    </p>

    <template v-if="deals.length">
      <Select
        v-if="deals.length > 1"
        v-model="dealId"
        :options="dealOptions"
        :aria-label="t('CRM.PANEL.SUMMARY.FOR_DEAL')"
        class="w-full"
      />
      <div class="flex flex-wrap items-center gap-2">
        <Button
          data-testid="save-note"
          :label="t('CRM.PANEL.SUMMARY.SAVE_NOTE')"
          size="xs"
          :disabled="!note.trim() || isSaving"
          @click="saveNote"
        />
        <Button
          v-if="hasSuggested"
          data-testid="apply-suggested"
          :label="t('CRM.PANEL.SUMMARY.APPLY')"
          size="xs"
          variant="faded"
          :disabled="isSaving"
          @click="apply"
        />
        <Button
          :label="t('CRM.PANEL.SUMMARY.CLOSE')"
          size="xs"
          variant="ghost"
          color="slate"
          @click="emit('close')"
        />
      </div>
    </template>
    <div v-else class="flex flex-wrap items-center gap-2">
      <Button
        data-testid="create-deal"
        :label="t('CRM.PANEL.SUMMARY.CREATE_DEAL')"
        size="xs"
        icon="i-lucide-briefcase"
        @click="createDeal"
      />
      <Button
        :label="t('CRM.PANEL.SUMMARY.CLOSE')"
        size="xs"
        variant="ghost"
        color="slate"
        @click="emit('close')"
      />
    </div>
  </section>
</template>
