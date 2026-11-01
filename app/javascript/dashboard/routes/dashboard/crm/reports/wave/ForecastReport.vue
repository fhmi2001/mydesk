<script setup>
// Custom (MyDesk): التقرير 7, how much will close by the end of the period (SalesCrm::Reports::ForecastCategories):
// won so far, then the open deals expected in it by forecast category, against the target.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';
import NumberTile from './NumberTile.vue';
import ReportSection from './ReportSection.vue';
import AssigneeTable from './AssigneeTable.vue';
import CellButton from './CellButton.vue';

const props = defineProps({
  data: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
});
const emit = defineEmits(['drill']);

const { t } = useI18n();
const { money, number } = useCrmFormat();
const L = key => t(`CRM.REPORTS.WAVE.FORECAST.${key}`);
const C = key => t(`CRM.REPORTS.WAVE.CATEGORIES.${key}`);
const drill = (cell, title) => emit('drill', cell, title);

const totals = computed(() => props.data.totals);
const percent = value => (value === null ? '—' : `${number(value)}%`);

// The bar: won, commit, best case, pipeline, one after the other, with the target marked on it
const SEGMENTS = [
  { key: 'won', color: 'bg-n-teal-9' },
  { key: 'commit', color: 'bg-n-iris-9' },
  { key: 'best_case', color: 'bg-n-iris-6' },
  { key: 'pipeline', color: 'bg-n-slate-6' },
];
const segmentValue = key =>
  key === 'won'
    ? totals.value.won_cents
    : totals.value.categories[key].total_cents;
const barTotal = computed(() =>
  Math.max(
    1,
    totals.value.target_cents,
    SEGMENTS.reduce((sum, s) => sum + segmentValue(s.key), 0)
  )
);
const segments = computed(() =>
  SEGMENTS.map(s => ({
    ...s,
    value: segmentValue(s.key),
    width: (segmentValue(s.key) / barTotal.value) * 100,
  }))
);
const targetAt = computed(
  () => (totals.value.target_cents / barTotal.value) * 100
);
const segmentLabel = key => (key === 'won' ? L('WON') : C(key));

const CATEGORY_ROWS = ['commit', 'best_case', 'pipeline', 'omitted'];

const assigneeColumns = computed(() => [
  {
    key: 'won_cents',
    label: L('WON'),
    format: 'money',
    cell: row => row.won_cell,
  },
  ...['commit', 'best_case', 'pipeline'].map(category => ({
    key: category,
    label: C(category),
    format: 'money',
    value: row => row.categories[category].total_cents,
    cell: row => row.categories[category].cell,
  })),
  { key: 'forecast_cents', label: L('FORECAST'), format: 'money' },
  { key: 'target_cents', label: L('TARGET'), format: 'money' },
  { key: 'forecast_attainment', label: L('ATTAINMENT'), format: 'percent' },
]);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
      <NumberTile
        :label="L('WON')"
        :value="money(totals.won_cents, currency)"
        :cell="totals.won_cell"
        tone="good"
        @drill="drill"
      />
      <NumberTile
        :label="L('FORECAST')"
        :value="money(totals.forecast_cents, currency)"
        :note="L('FORECAST_NOTE')"
      />
      <NumberTile
        :label="L('BEST_CASE')"
        :value="money(totals.best_case_cents, currency)"
        :note="L('BEST_CASE_NOTE')"
      />
      <NumberTile
        :label="L('TARGET')"
        :value="money(totals.target_cents, currency)"
        :note="
          totals.target_cents
            ? `${L('ATTAINMENT')}: ${percent(totals.forecast_attainment)}`
            : L('NO_TARGET')
        "
      />
    </div>

    <ReportSection :title="L('AGAINST_TARGET')">
      <div class="relative">
        <div class="flex h-4 overflow-hidden rounded-full bg-n-slate-3">
          <div
            v-for="segment in segments"
            :key="segment.key"
            :class="segment.color"
            :style="{ width: `${segment.width}%` }"
            :title="`${segmentLabel(segment.key)}: ${money(segment.value, currency)}`"
          />
        </div>
        <div
          v-if="totals.target_cents"
          class="absolute -top-1 -bottom-1 w-0.5 bg-n-slate-12"
          :style="{ insetInlineStart: `${targetAt}%` }"
          aria-hidden="true"
        />
      </div>
      <ul
        class="flex flex-wrap gap-x-4 gap-y-1 mt-3 text-label-small text-n-slate-11"
      >
        <li
          v-for="segment in segments"
          :key="segment.key"
          class="inline-flex items-center gap-1.5"
        >
          <span
            class="size-2.5 rounded-sm"
            :class="segment.color"
            aria-hidden="true"
          />
          {{ segmentLabel(segment.key) }}
          <bdi class="tabular-nums text-n-slate-12">
            {{ money(segment.value, currency) }}
          </bdi>
        </li>
        <li v-if="totals.target_cents" class="inline-flex items-center gap-1.5">
          <span class="w-0.5 h-3 bg-n-slate-12" aria-hidden="true" />
          {{ L('TARGET') }}
        </li>
      </ul>
      <p v-if="totals.gap_cents" class="mt-3 text-body-main text-n-slate-11">
        {{ L('GAP') }}
        <bdi class="font-medium tabular-nums text-n-ruby-11">
          {{ money(totals.gap_cents, currency) }}
        </bdi>
      </p>
    </ReportSection>

    <ReportSection :title="L('BY_CATEGORY')" :note="L('CATEGORY_HINT')">
      <div class="overflow-x-auto">
        <table class="w-full text-body-main">
          <thead>
            <tr class="text-label-small text-n-slate-11">
              <th scope="col" class="py-2 font-medium text-start">
                {{ L('CATEGORY') }}
              </th>
              <th scope="col" class="py-2 font-medium text-end">
                {{ L('COUNT') }}
              </th>
              <th scope="col" class="py-2 font-medium text-end">
                {{ L('VALUE') }}
              </th>
              <th scope="col" class="py-2 font-medium text-end">
                {{ L('WEIGHTED') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak">
            <tr
              v-for="key in CATEGORY_ROWS"
              :key="key"
              :class="{ 'text-n-slate-10': key === 'omitted' }"
            >
              <th scope="row" class="py-2.5 font-normal text-start">
                {{ C(key) }}
              </th>
              <td class="py-2.5 text-end">
                <CellButton
                  :cell="totals.categories[key].cell"
                  :label="number(totals.categories[key].count)"
                  :title="C(key)"
                  :empty="!totals.categories[key].count"
                  @drill="drill"
                />
              </td>
              <td class="py-2.5 text-end tabular-nums" dir="auto">
                {{ money(totals.categories[key].total_cents, currency) }}
              </td>
              <td
                class="py-2.5 text-end tabular-nums text-n-slate-11"
                dir="auto"
              >
                {{ money(totals.categories[key].weighted_cents, currency) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </ReportSection>

    <ReportSection v-if="data.assignees" :title="L('BY_ASSIGNEE')">
      <AssigneeTable
        :rows="data.assignees"
        :columns="assigneeColumns"
        :currency="currency"
        @drill="drill"
      />
    </ReportSection>
  </div>
</template>
