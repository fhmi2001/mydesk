<script setup>
// Custom (MyDesk): the tokens the assistant used and what they cost, this month per kind of call and per month
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { USAGE_KINDS, sumTotals, useUsageFormat } from './useUsageFormat';

const props = defineProps({
  usage: { type: Object, required: true },
});

const { t, locale } = useI18n();
const { formatNumber, formatUsd, formatSar } = useUsageFormat();

const HEADER_CELL =
  'px-4 py-2.5 text-xs font-medium text-start text-n-slate-11 whitespace-nowrap';
const CELL =
  'px-4 py-2.5 text-sm tabular-nums text-n-slate-12 whitespace-nowrap';

const thisMonth = computed(() => props.usage.tokens.this_month);
const total = computed(() => sumTotals(thisMonth.value));
const rows = computed(() =>
  USAGE_KINDS.map(kind => ({
    kind,
    ...sumTotals({ [kind]: thisMonth.value[kind] }),
  }))
);

const monthFormat = computed(
  () =>
    new Intl.DateTimeFormat(locale.value, { month: 'long', year: 'numeric' })
);
// Newest month first; the API dates are the first day of each month
const months = computed(() =>
  [...props.usage.tokens.months].reverse().map(month => ({
    ...month,
    label: monthFormat.value.format(new Date(`${month.month}T00:00:00`)),
    tokens:
      Number(month.input_tokens) +
      Number(month.output_tokens) +
      Number(month.cached_tokens),
  }))
);

const summary = computed(() => [
  {
    key: 'tokens',
    label: t('SMART_ASSISTANT.USAGE_REPORT.TOKENS'),
    value: formatNumber(
      total.value.input_tokens +
        total.value.output_tokens +
        total.value.cached_tokens
    ),
    detail: t('SMART_ASSISTANT.USAGE_REPORT.TOKENS_SPLIT', {
      input: formatNumber(total.value.input_tokens + total.value.cached_tokens),
      output: formatNumber(total.value.output_tokens),
    }),
  },
  {
    key: 'cost',
    label: t('SMART_ASSISTANT.USAGE_REPORT.COST'),
    value: formatUsd(total.value.cost),
    detail: t('SMART_ASSISTANT.USAGE_REPORT.IN_SAR', {
      amount: formatSar(total.value.cost),
    }),
  },
  {
    key: 'calls',
    label: t('SMART_ASSISTANT.USAGE_REPORT.CALLS'),
    value: formatNumber(total.value.calls),
  },
]);
</script>

<template>
  <section class="flex flex-col gap-6">
    <div class="flex flex-col gap-1">
      <h2 class="text-heading-2 text-n-slate-12">
        {{ t('SMART_ASSISTANT.USAGE_REPORT.TITLE') }}
      </h2>
      <p class="text-sm text-n-slate-11">
        {{ t('SMART_ASSISTANT.USAGE_REPORT.HINT', { model: usage.model }) }}
      </p>
    </div>

    <dl
      class="grid grid-cols-1 gap-px overflow-hidden sm:grid-cols-3 rounded-xl bg-n-weak outline outline-1 -outline-offset-1 outline-n-weak"
    >
      <div
        v-for="item in summary"
        :key="item.key"
        class="flex flex-col gap-1 px-4 py-3 bg-n-card"
      >
        <dt class="text-xs text-n-slate-11">{{ item.label }}</dt>
        <dd class="text-xl font-semibold tabular-nums text-n-slate-12">
          {{ item.value }}
        </dd>
        <dd v-if="item.detail" class="text-xs tabular-nums text-n-slate-11">
          {{ item.detail }}
        </dd>
      </div>
    </dl>

    <div class="flex flex-col gap-3">
      <h3 class="text-heading-3 text-n-slate-12">
        {{ t('SMART_ASSISTANT.USAGE_REPORT.BY_KIND') }}
      </h3>
      <div
        class="overflow-x-auto rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
      >
        <table class="w-full min-w-[36rem]">
          <thead class="bg-n-alpha-1">
            <tr>
              <th :class="HEADER_CELL">
                {{ t('SMART_ASSISTANT.USAGE_REPORT.HEADERS.KIND') }}
              </th>
              <th :class="HEADER_CELL">
                {{ t('SMART_ASSISTANT.USAGE_REPORT.HEADERS.CALLS') }}
              </th>
              <th :class="HEADER_CELL">
                {{ t('SMART_ASSISTANT.USAGE_REPORT.HEADERS.INPUT') }}
              </th>
              <th :class="HEADER_CELL">
                {{ t('SMART_ASSISTANT.USAGE_REPORT.HEADERS.OUTPUT') }}
              </th>
              <th :class="HEADER_CELL">
                {{ t('SMART_ASSISTANT.USAGE_REPORT.HEADERS.COST') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak">
            <tr v-for="row in rows" :key="row.kind">
              <td :class="CELL">
                {{ t(`SMART_ASSISTANT.USAGE_REPORT.KINDS.${row.kind}`) }}
              </td>
              <td :class="CELL">{{ formatNumber(row.calls) }}</td>
              <td :class="CELL">
                {{ formatNumber(row.input_tokens + row.cached_tokens) }}
              </td>
              <td :class="CELL">{{ formatNumber(row.output_tokens) }}</td>
              <td :class="CELL">{{ formatUsd(row.cost) }}</td>
            </tr>
            <tr class="bg-n-alpha-1">
              <td :class="CELL" class="font-medium">
                {{ t('SMART_ASSISTANT.USAGE_REPORT.TOTAL') }}
              </td>
              <td :class="CELL" class="font-medium">
                {{ formatNumber(total.calls) }}
              </td>
              <td :class="CELL" class="font-medium">
                {{ formatNumber(total.input_tokens + total.cached_tokens) }}
              </td>
              <td :class="CELL" class="font-medium">
                {{ formatNumber(total.output_tokens) }}
              </td>
              <td :class="CELL" class="font-medium">
                {{ formatUsd(total.cost) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="flex flex-col gap-3">
      <h3 class="text-heading-3 text-n-slate-12">
        {{ t('SMART_ASSISTANT.USAGE_REPORT.BY_MONTH') }}
      </h3>
      <p v-if="!months.length" class="text-sm text-n-slate-11">
        {{ t('SMART_ASSISTANT.USAGE_REPORT.EMPTY') }}
      </p>
      <div
        v-else
        class="overflow-x-auto rounded-xl outline outline-1 -outline-offset-1 outline-n-weak"
      >
        <table class="w-full min-w-[28rem]">
          <thead class="bg-n-alpha-1">
            <tr>
              <th :class="HEADER_CELL">
                {{ t('SMART_ASSISTANT.USAGE_REPORT.HEADERS.MONTH') }}
              </th>
              <th :class="HEADER_CELL">
                {{ t('SMART_ASSISTANT.USAGE_REPORT.HEADERS.TOKENS') }}
              </th>
              <th :class="HEADER_CELL">
                {{ t('SMART_ASSISTANT.USAGE_REPORT.HEADERS.COST') }}
              </th>
              <th :class="HEADER_CELL">
                {{ t('SMART_ASSISTANT.USAGE_REPORT.HEADERS.COST_SAR') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak">
            <tr v-for="month in months" :key="month.month">
              <td :class="CELL">{{ month.label }}</td>
              <td :class="CELL">{{ formatNumber(month.tokens) }}</td>
              <td :class="CELL">{{ formatUsd(month.cost) }}</td>
              <td :class="CELL">{{ formatSar(month.cost) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </section>
</template>
