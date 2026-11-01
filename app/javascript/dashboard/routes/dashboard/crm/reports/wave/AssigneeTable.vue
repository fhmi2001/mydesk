<script setup>
// Custom (MyDesk): the manager's row per employee in a report. columns: [{ key, label, format, cell?, tone? }]
// format: money | count | percent | times; `cell(row)` makes the number open its deals; `tone(row)` colours it.
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';
import CellButton from './CellButton.vue';

const props = defineProps({
  rows: { type: Array, required: true },
  columns: { type: Array, required: true },
  currency: { type: String, default: 'SAR' },
  ranked: { type: Boolean, default: false },
});
const emit = defineEmits(['drill']);

const { t } = useI18n();
const { money, number } = useCrmFormat();

const name = row => row.name || t('CRM.COMMON.UNASSIGNED');
const value = (row, column) => column.value?.(row) ?? row[column.key];
const format = (row, column) => {
  const v = value(row, column);
  if (v === null || v === undefined) return '—';
  if (column.format === 'money') return money(v, props.currency);
  if (column.format === 'percent') return `${number(v)}%`;
  if (column.format === 'times') return `${number(v)}×`;
  if (column.format === 'text') return v;
  return number(v);
};
const toneClass = (row, column) =>
  ({
    good: 'text-n-teal-11',
    warn: 'text-n-amber-11',
    bad: 'text-n-ruby-11 font-medium',
  })[column.tone?.(row)] || '';
</script>

<template>
  <div class="overflow-x-auto">
    <table class="w-full text-body-main">
      <thead>
        <tr class="text-label-small text-n-slate-11">
          <th
            v-if="ranked"
            scope="col"
            class="py-2 pe-2 font-medium text-start"
          >
            #
          </th>
          <th scope="col" class="py-2 font-medium text-start">
            {{ t('CRM.REPORTS.AGENTS.AGENT') }}
          </th>
          <th
            v-for="column in columns"
            :key="column.key"
            scope="col"
            class="py-2 ps-3 font-medium text-end"
          >
            {{ column.label }}
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-n-weak">
        <tr v-for="row in rows" :key="row.assignee_id ?? 'none'">
          <td v-if="ranked" class="py-2.5 pe-2 tabular-nums text-n-slate-10">
            {{ number(row.rank) }}
          </td>
          <th scope="row" class="py-2.5 font-normal text-start text-n-slate-12">
            {{ name(row) }}
          </th>
          <td
            v-for="column in columns"
            :key="column.key"
            class="py-2.5 ps-3 text-end tabular-nums"
            :class="toneClass(row, column)"
          >
            <CellButton
              v-if="column.cell"
              :cell="column.cell(row)"
              :label="format(row, column)"
              :title="`${name(row)} · ${column.label}`"
              :empty="!value(row, column)"
              @drill="(cell, title) => emit('drill', cell, title)"
            />
            <span v-else dir="auto">{{ format(row, column) }}</span>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
