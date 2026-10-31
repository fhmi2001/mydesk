<script setup>
// Custom (MyDesk): the deals as a sortable table (open deals, or the deleted ones with restore). Every deal title
// is a link and every column header a button, so the table works from the keyboard and announces its sort.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
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
const { accountScopedRoute } = useAccount();

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

const ariaSort = key => {
  if (sortKey.value !== key) return 'none';
  return sortDir.value === 'asc' ? 'ascending' : 'descending';
};

const dealRoute = deal => accountScopedRoute('crm_deal', { dealId: deal.id });
</script>

<template>
  <div class="flex-1 min-h-0 px-6 pb-6 overflow-auto">
    <table
      class="w-full border-separate border-spacing-0 text-body-main min-w-[56rem]"
    >
      <thead class="sticky top-0 z-10 bg-n-surface-1">
        <tr>
          <th
            v-for="column in columns"
            :key="column.key"
            scope="col"
            :aria-sort="ariaSort(column.key)"
            class="p-0 border-b border-n-weak"
          >
            <button
              type="button"
              class="flex items-center w-full gap-1 px-3 py-2 whitespace-nowrap text-heading-3 text-n-slate-11 hover:text-n-slate-12 focus-visible:outline-2 focus-visible:outline-n-brand"
              :class="column.numeric ? 'justify-end' : 'justify-start'"
              @click="toggleSort(column.key)"
            >
              {{ column.label }}
              <span
                v-if="sortKey === column.key"
                class="size-3"
                :class="
                  sortDir === 'asc'
                    ? 'i-lucide-arrow-up'
                    : 'i-lucide-arrow-down'
                "
                aria-hidden="true"
              />
            </button>
          </th>
          <th v-if="discarded" scope="col" class="border-b border-n-weak">
            <span class="sr-only">{{ t('CRM.DEALS.RESTORE') }}</span>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="deal in sorted"
          :key="deal.id"
          class="hover:bg-n-alpha-2"
          :data-deal-id="deal.id"
        >
          <td class="max-w-64 px-3 py-2.5 border-b border-n-weak truncate">
            <router-link
              v-if="!discarded"
              :to="dealRoute(deal)"
              class="font-medium text-n-slate-12 hover:underline focus-visible:outline-2 focus-visible:outline-n-brand rounded"
              @click.prevent="emit('open', deal)"
            >
              {{ deal.title }}
            </router-link>
            <span v-else class="font-medium text-n-slate-12">
              {{ deal.title }}
            </span>
          </td>
          <td
            class="px-3 py-2.5 border-b border-n-weak text-end tabular-nums"
            dir="auto"
          >
            {{ money(deal.amount_cents, deal.currency || currency) }}
          </td>
          <td class="px-3 py-2.5 border-b border-n-weak text-n-slate-11">
            <span class="inline-flex items-center gap-1.5">
              <span
                class="size-2 rounded-full"
                :style="{ backgroundColor: stagesById[deal.stage_id]?.color }"
                aria-hidden="true"
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
            class="px-3 py-2.5 border-b border-n-weak text-n-slate-11 whitespace-nowrap tabular-nums"
          >
            {{ deal.close_date ? date(deal.close_date) : '—' }}
          </td>
          <td class="px-3 py-2.5 border-b border-n-weak">
            <StatusBadge :status="deal.status" />
          </td>
          <td
            class="px-3 py-2.5 border-b border-n-weak text-n-slate-11 whitespace-nowrap tabular-nums"
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
              @click="emit('restore', deal)"
            />
          </td>
        </tr>
      </tbody>
    </table>
    <p
      v-if="!deals.length"
      class="py-10 text-center text-body-main text-n-slate-11"
    >
      {{ t('CRM.DEALS.EMPTY_SEARCH') }}
    </p>
  </div>
</template>
