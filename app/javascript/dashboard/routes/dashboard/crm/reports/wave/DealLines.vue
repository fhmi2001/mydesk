<script setup>
// Custom (MyDesk): the deals a report lists (SalesCrm::Reports::Report#line), with the columns that report needs.
// Each title opens the deal.
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';

defineProps({
  deals: { type: Array, required: true },
  columns: { type: Array, default: () => ['stage', 'close_date'] },
  currency: { type: String, default: 'SAR' },
  showAssignee: { type: Boolean, default: false },
});

const { t } = useI18n();
const { money, number, date } = useCrmFormat();

const heading = column => t(`CRM.REPORTS.WAVE.COLUMNS.${column}`);
const days = value =>
  value === null || value === undefined ? '—' : number(value);
</script>

<template>
  <div class="overflow-x-auto">
    <table class="w-full text-body-main">
      <thead>
        <tr class="text-label-small text-n-slate-11">
          <th scope="col" class="py-2 font-medium text-start">
            {{ heading('title') }}
          </th>
          <th
            v-if="showAssignee"
            scope="col"
            class="py-2 font-medium text-start"
          >
            {{ heading('assignee') }}
          </th>
          <th
            v-for="column in columns"
            :key="column"
            scope="col"
            class="py-2 font-medium text-start"
          >
            {{ heading(column) }}
          </th>
          <th scope="col" class="py-2 font-medium text-end">
            {{ heading('amount') }}
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-n-weak">
        <tr v-for="deal in deals" :key="deal.id">
          <th scope="row" class="py-2.5 pe-3 font-normal text-start">
            <router-link
              :to="{ name: 'crm_deal', params: { dealId: deal.id } }"
              class="text-n-slate-12 hover:text-n-brand hover:underline"
            >
              {{ deal.title }}
            </router-link>
            <span
              v-if="deal.contact_name"
              class="block text-label-small text-n-slate-10"
            >
              {{ deal.contact_name }}
            </span>
          </th>
          <td v-if="showAssignee" class="py-2.5 pe-3 text-n-slate-11">
            {{ deal.assignee?.name || t('CRM.COMMON.UNASSIGNED') }}
          </td>
          <td
            v-for="column in columns"
            :key="column"
            class="py-2.5 pe-3 text-n-slate-11 tabular-nums whitespace-nowrap"
          >
            <span
              v-if="column === 'stage'"
              class="inline-flex items-center gap-1.5"
            >
              <span
                class="rounded-full size-2 shrink-0"
                :style="{ backgroundColor: deal.stage?.color }"
                aria-hidden="true"
              />
              {{ deal.stage?.name }}
            </span>
            <template v-else-if="column === 'close_date'">
              {{ deal.close_date ? date(deal.close_date) : '—' }}
            </template>
            <template v-else-if="column === 'probability'">
              {{ `${deal.probability}%` }}
            </template>
            <template v-else-if="column === 'category'">
              {{ t(`CRM.REPORTS.WAVE.CATEGORIES.${deal.forecast_category}`) }}
            </template>
            <span
              v-else-if="column === 'days_overdue'"
              :class="{ 'text-n-ruby-11 font-medium': deal.days_overdue }"
            >
              {{ days(deal.days_overdue) }}
            </span>
            <span v-else-if="column === 'issues'" class="flex flex-wrap gap-1">
              <span
                v-for="issue in deal.issues"
                :key="issue"
                class="px-1.5 py-0.5 rounded bg-n-ruby-3 text-n-ruby-11 text-label-small whitespace-nowrap"
              >
                {{ t(`CRM.REPORTS.WAVE.ISSUE_CHIPS.${issue}`) }}
              </span>
            </span>
            <span
              v-else-if="column === 'status'"
              :class="
                deal.status === 'won' ? 'text-n-teal-11' : 'text-n-ruby-11'
              "
            >
              {{ t(`CRM.COMMON.${deal.status.toUpperCase()}`) }}
            </span>
            <template v-else-if="column === 'closed_at'">
              {{ date(deal.won_at || deal.lost_at) }}
            </template>
            <template v-else-if="column === 'lost_reason'">
              {{ deal.lost_reason || '—' }}
            </template>
            <template v-else>{{ days(deal[column]) }}</template>
          </td>
          <td class="py-2.5 text-end tabular-nums text-n-slate-12" dir="auto">
            {{ money(deal.amount_cents, deal.currency || currency) }}
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
