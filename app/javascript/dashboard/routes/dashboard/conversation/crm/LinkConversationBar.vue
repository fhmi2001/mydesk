<script setup>
// Custom (MyDesk): this is a new conversation of a customer whose open deal is followed in another one (decision ح,
// CONVERSATION_SALES_PLAN.md). One click follows the deal here from now on; with several deals the user picks one.
// Shown to the deal's owner and administrators only (the server lists no other deals).
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
  deals: { type: Array, required: true },
  isLinking: { type: Boolean, default: false },
});
const emit = defineEmits(['link']);
const { t } = useI18n();

const dealId = ref('');
watch(
  () => props.deals,
  deals => {
    dealId.value = deals[0] ? String(deals[0].id) : '';
  },
  { immediate: true }
);
const options = computed(() =>
  props.deals.map(deal => ({ value: String(deal.id), label: deal.title }))
);
const chosen = computed(() =>
  props.deals.find(deal => String(deal.id) === dealId.value)
);
</script>

<template>
  <section
    class="flex flex-col gap-2 p-3 rounded-lg bg-n-amber-2 outline outline-1 -outline-offset-1 outline-n-amber-5"
    :aria-label="t('CRM.PANEL.LINK.LABEL')"
  >
    <p class="flex items-start gap-1.5 text-body-main text-n-slate-12">
      <span
        class="i-lucide-messages-square size-4 mt-0.5 shrink-0 text-n-amber-11"
        aria-hidden="true"
      />
      <span>
        {{
          deals.length === 1
            ? t('CRM.PANEL.LINK.ONE', { title: deals[0].title })
            : t('CRM.PANEL.LINK.SEVERAL', { count: deals.length })
        }}
      </span>
    </p>
    <Select
      v-if="deals.length > 1"
      v-model="dealId"
      :options="options"
      :aria-label="t('CRM.PANEL.LINK.PICK')"
      class="w-full"
    />
    <Button
      :label="t('CRM.PANEL.LINK.ACTION')"
      size="xs"
      variant="faded"
      color="slate"
      icon="i-lucide-link"
      class="self-start"
      :is-loading="isLinking"
      :disabled="!chosen || isLinking"
      @click="emit('link', chosen)"
    />
  </section>
</template>
