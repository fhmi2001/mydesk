<script setup>
// Custom (MyDesk): the deals as a sortable table (open deals, or the deleted ones with restore)
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import StatusBadge from '../shared/StatusBadge.vue';
import { useCrmFormat } from '../shared/useCrmFormat';

const props = defineProps({
  deals: { type: Array, required: true },
  stagesById: { type: Object, default: () => ({}) },
  currency: { type: String, default: 'SAR' },
  discarded: { type: Boolean, default: false },
});
const emit = defineEmits(['open', 'restore']);
const { t } = useI18n();
const { money, date, dateTime } = useCrmFormat();

const sortKey = ref('updated_at');
const sortDir = ref('desc');

const columns = computed(() => [
  { key: 'title', label: t('CRM.DEALS.COLUMNS.TITLE') },
  { key: 'amount_cents', label: t('CRM.DEALS.COLUMNS.AMOUNT'), numeric: true },
  { key: 'stage_id', label: t('CRM.DEALS.COLUMNS.STAGE') },
  { key: 'contact_name', label: t('CRM.DEALS.COLUMNS.CONTACT') },
  { key: 'assignee', label: t('CRM.DEALS.COLUMNS.ASSIGNEE') },
  { key: 'close_date', label: t('CRM.DEALS.COLUMNS.CLOSE_DATE') },
  { key: 'status', label: t('CRM.DEALS.COLUMNS.STATUS') },
  {
    key: props.discarded ? 'discarded_at' : 'updated_at',
    label: props.discarded
      ? t('CRM.DEALS.COLUMNS.DELETED_AT')
      : t('CRM.DEALS.COLUMNS.UPDATED'),
  },
]);

const sortValue = (deal, key) => {
  if (key === 'assignee') return deal.assignee?.name || '';
  if (key === 'stage_id') return props.stagesById[deal.stage_id]?.position ?? 0;
  return deal[key] ?? '';
};

const sorted = computed(() =>
  [...props.deals].sort((a, b) => {
    const av = sortValue(a, sortKey.value);
    const bv = sortValue(b, sortKey.value);
    const cmp =
      typeof av === 'number' && typeof bv === 'number'
        ? av - bv
        : String(av).localeCompare(String(bv), undefined, { numeric: true });
    return sortDir.value === 'asc' ? cmp : -cmp;
  })
);

const toggleSort = key => {
  if (sortKey.value === key)
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc';
  else {
    sortKey.value = key;
    sortDir.value = 'asc';
  }
};
</script>

<template>
  <div class="flex-1 min-h-0 overflow-auto px-6 pb-6">
    <table class="w-full text-sm border-separate border-spacing-0">
      <thead class="sticky top-0 z-10 bg-n-surface-1">
        <tr>
          <th
            v-for="column in columns"
            :key="column.key"
            class="px-3 py-2 text-xs font-medium text-start text-n-slate-11 border-b border-n-weak cursor-pointer select-none whitespace-nowrap"
            :class="{ 'text-end': column.numeric }"
            @click="toggleSort(column.key)"
          >
            <span class="inline-flex items-center gap-1">
              {{ column.label }}
              <span
                v-if="sortKey === column.key"
                class="size-3"
                :class="
                  sortDir === 'asc'
                    ? 'i-lucide-arrow-up'
                    : 'i-lucide-arrow-down'
                "
              />
            </span>
          </th>
          <th v-if="discarded" class="border-b border-n-weak" />
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="deal in sorted"
          :key="deal.id"
          class="hover:bg-n-slate-2 cursor-pointer"
          @click="emit('open', deal)"
        >
          <td
            class="px-3 py-2.5 border-b border-n-weak text-n-slate-12 font-medium max-w-64 truncate"
          >
            {{ deal.title }}
          </td>
          <td
            class="px-3 py-2.5 border-b border-n-weak text-end tabular-nums"
            dir="auto"
          >
            {{ money(deal.amount_cents, deal.currency || currency) }}
          </td>
          <td class="px-3 py-2.5 border-b border-n-weak">
            <span class="inline-flex items-center gap-1.5">
              <span
                class="size-2 rounded-full"
                :style="{ backgroundColor: stagesById[deal.stage_id]?.color }"
              />
              {{ stagesById[deal.stage_id]?.name || '—' }}
            </span>
          </td>
          <td class="px-3 py-2.5 border-b border-n-weak text-n-slate-11">
            {{ deal.contact_name || '—' }}
          </td>
          <td class="px-3 py-2.5 border-b border-n-weak text-n-slate-11">
            {{ deal.assignee?.name || t('CRM.COMMON.NO_ASSIGNEE') }}
          </td>
          <td
            class="px-3 py-2.5 border-b border-n-weak text-n-slate-11 whitespace-nowrap"
          >
            {{ deal.close_date ? date(deal.close_date) : '—' }}
          </td>
          <td class="px-3 py-2.5 border-b border-n-weak">
            <StatusBadge :status="deal.status" />
          </td>
          <td
            class="px-3 py-2.5 border-b border-n-weak text-n-slate-11 whitespace-nowrap"
          >
            {{ dateTime(discarded ? deal.discarded_at : deal.updated_at) }}
          </td>
          <td
            v-if="discarded"
            class="px-3 py-2.5 border-b border-n-weak text-end"
          >
            <Button
              :label="t('CRM.DEALS.RESTORE')"
              size="xs"
              variant="faded"
              icon="i-lucide-undo-2"
              @click.stop="emit('restore', deal)"
            />
          </td>
        </tr>
      </tbody>
    </table>
    <p v-if="!deals.length" class="py-10 text-center text-sm text-n-slate-11">
      {{ t('CRM.DEALS.EMPTY_SEARCH') }}
    </p>
  </div>
</template>
