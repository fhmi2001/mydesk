<script setup>
// Custom (MyDesk): on a conversation card, the customer's open deals the user may see (CONVERSATION_SALES_PLAN.md, أ4):
// the stage of the biggest one, as a dot in its colour with its name, and the total. Nothing when there is none or the
// Sales section is off.
import { computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useCrmFormat } from 'dashboard/routes/dashboard/crm/shared/useCrmFormat';
import { badges, requestBadge } from './dealBadges';

const props = defineProps({
  contactId: { type: [Number, String], default: null },
});
const { t } = useI18n();
const { compactMoney } = useCrmFormat();
const enabled = useMapGetter('crm/status/isEnabled');

const ask = () => {
  if (enabled.value && props.contactId) requestBadge(props.contactId);
};
onMounted(ask);
watch(() => [props.contactId, enabled.value], ask);

const badge = computed(() =>
  enabled.value && props.contactId ? badges[String(props.contactId)] : null
);
const total = computed(() =>
  compactMoney(badge.value.total_cents, badge.value.currency)
);
</script>

<template>
  <span
    v-if="badge"
    class="inline-flex items-center gap-1 min-w-0 px-1.5 py-0.5 rounded-md bg-n-alpha-2 text-label-small text-n-slate-11"
    :title="
      t('CRM.BADGE.TITLE', { count: badge.count, stage: badge.stage?.name })
    "
  >
    <span
      data-testid="deal-badge-dot"
      class="rounded-full size-1.5 shrink-0"
      :style="{ background: badge.stage?.color }"
      aria-hidden="true"
    />
    <span class="truncate">{{ badge.stage?.name }}</span>
    <span class="tabular-nums shrink-0" dir="auto">{{ `· ${total}` }}</span>
    <span v-if="badge.count > 1" class="shrink-0">
      {{ t('CRM.BADGE.MORE', { count: badge.count - 1 }) }}
    </span>
  </span>
</template>
