<script setup>
// Custom (MyDesk): a deal's activity log, newest first
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../shared/useCrmFormat';

const props = defineProps({
  activities: { type: Array, required: true },
  stagesById: { type: Object, default: () => ({}) },
  currency: { type: String, default: 'SAR' },
});
const { t } = useI18n();
const { money, dateTime } = useCrmFormat();

const icons = {
  created: 'i-lucide-plus-circle',
  stage_changed: 'i-lucide-arrow-right-left',
  amount_changed: 'i-lucide-coins',
  assignee_changed: 'i-lucide-user-round',
  priority_changed: 'i-lucide-flag',
  won: 'i-lucide-trophy',
  lost: 'i-lucide-x-circle',
  reopened: 'i-lucide-rotate-ccw',
  note_added: 'i-lucide-sticky-note',
  task_added: 'i-lucide-list-plus',
  task_done: 'i-lucide-check-circle-2',
  discarded: 'i-lucide-trash-2',
  restored: 'i-lucide-undo-2',
};

const describe = activity => {
  const data = activity.data || {};
  return t(`CRM.DEALS.ACTIVITY.${activity.kind}`, {
    stage: props.stagesById[data.to_stage_id]?.name || '—',
    amount: money(data.to, props.currency),
    reason: data.note
      ? `${data.reason || ''} (${data.note})`
      : data.reason || '',
    title: data.title || '',
    ...(activity.kind === 'priority_changed' && {
      from: t(`CRM.DEALS.PRIORITIES.${data.from || 'medium'}`),
      to: t(`CRM.DEALS.PRIORITIES.${data.to || 'medium'}`),
    }),
  });
};

const rows = computed(() =>
  props.activities.map(activity => ({
    ...activity,
    icon: icons[activity.kind] || 'i-lucide-dot',
    text: describe(activity),
    who: activity.user?.name || t('CRM.DEALS.ACTIVITY.SYSTEM'),
    when: dateTime(activity.created_at),
  }))
);
</script>

<template>
  <ol v-if="rows.length" class="flex flex-col gap-3">
    <li v-for="row in rows" :key="row.id" class="flex items-start gap-3">
      <span
        class="flex items-center justify-center mt-0.5 rounded-full size-7 shrink-0 bg-n-slate-3 text-n-slate-11"
      >
        <span :class="row.icon" class="size-4" />
      </span>
      <div class="min-w-0 text-body-main">
        <p class="text-n-slate-12">
          <span class="font-medium">{{ row.who }}</span> {{ row.text }}
        </p>
        <p class="text-label-small text-n-slate-10">{{ row.when }}</p>
      </div>
    </li>
  </ol>
  <p v-else class="text-body-main text-n-slate-11">
    {{ t('CRM.DEALS.DETAIL.NO_ACTIVITY') }}
  </p>
</template>
