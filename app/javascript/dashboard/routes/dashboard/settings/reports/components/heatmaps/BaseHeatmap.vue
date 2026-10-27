<script setup>
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'vue';
import { HeatmapChart } from '@chatwoot/viz';

import getDay from 'date-fns/getDay';

import { groupHeatmapByDay } from 'helpers/ReportsDataHelper';
import { formatReportDate } from 'dashboard/helper/reportFormatters';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  heatmapData: {
    type: Array,
    default: () => [],
  },
  numberOfRows: {
    type: Number,
    default: 7,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  colorScheme: {
    type: String,
    default: 'blue',
    validator: value => ['blue', 'green'].includes(value),
  },
  ariaLabel: {
    type: String,
    required: true,
  },
  formatValue: {
    type: Function,
    required: true,
  },
});
const { t, locale } = useI18n();

// Custom (MyDesk): the row date in the user's language, not date-fns English
function formatDate(dateString) {
  // Day and month only: the range picker already states the year, and rows stay one short line
  return formatReportDate(new Date(dateString), 'day', locale?.value);
}

const DAYS_OF_WEEK = [
  t('DAYS_OF_WEEK.SUNDAY'),
  t('DAYS_OF_WEEK.MONDAY'),
  t('DAYS_OF_WEEK.TUESDAY'),
  t('DAYS_OF_WEEK.WEDNESDAY'),
  t('DAYS_OF_WEEK.THURSDAY'),
  t('DAYS_OF_WEEK.FRIDAY'),
  t('DAYS_OF_WEEK.SATURDAY'),
];

const columns = Array.from({ length: 24 }, (_, hour) => ({
  id: hour,
  label: `${String(hour).padStart(2, '0')}:00`,
}));

const QUANTILES = [0.2, 0.4, 0.6, 0.8, 0.9, 0.99];

const COLOR_SCHEMES = {
  blue: [
    'rgb(var(--blue-3))',
    'rgb(var(--blue-5))',
    'rgb(var(--blue-7))',
    'rgb(var(--blue-8))',
    'rgb(var(--blue-9))',
    'rgb(var(--blue-10))',
    'rgb(var(--blue-11))',
  ],
  green: [
    'rgb(var(--teal-3))',
    'rgb(var(--teal-5))',
    'rgb(var(--teal-7))',
    'rgb(var(--teal-8))',
    'rgb(var(--teal-9))',
    'rgb(var(--teal-10))',
    'rgb(var(--teal-11))',
  ],
};

const chartData = computed(() => {
  const groupedData = groupHeatmapByDay(props.heatmapData);
  const rows = Array.from(groupedData.entries()).map(([dateKey, rowData]) => {
    const valuesByHour = new Map(rowData.map(item => [item.hour, item]));
    const date = new Date(dateKey);

    return {
      id: dateKey,
      label: DAYS_OF_WEEK[getDay(date)],
      description: formatDate(dateKey),
      data: columns.map(({ id }) => valuesByHour.get(id) ?? null),
    };
  });

  return { columns, rows };
});

const heatmapColors = computed(() => COLOR_SCHEMES[props.colorScheme]);

// Custom (MyDesk): the chart makes all 168 cells tab stops; keep one in the tab order and move
// between cells with the arrow keys (roving tabindex), mirrored for right-to-left layouts.
const COLUMN_COUNT = 24;
const gridRef = ref(null);
let observer;

const focusableCells = () => [
  ...(gridRef.value?.querySelectorAll('.cw-viz-heatmap__cell') ?? []),
];

const setActiveCell = (cells, active) => {
  cells.forEach(cell =>
    cell.setAttribute('tabindex', cell === active ? '0' : '-1')
  );
};

const applyRovingTabindex = () => {
  const cells = focusableCells();
  if (!cells.length) return;
  const current = cells.find(cell => cell.getAttribute('tabindex') === '0');
  setActiveCell(cells, current ?? cells[0]);
};

const KEY_STEPS = { ArrowDown: COLUMN_COUNT, ArrowUp: -COLUMN_COUNT };

const onGridKeydown = event => {
  const cells = focusableCells();
  const index = cells.indexOf(document.activeElement);
  if (index === -1) return;

  const isRtl = getComputedStyle(gridRef.value).direction === 'rtl';
  const rowStart = index - (index % COLUMN_COUNT);
  const steps = {
    ...KEY_STEPS,
    ArrowRight: isRtl ? -1 : 1,
    ArrowLeft: isRtl ? 1 : -1,
    Home: rowStart - index,
    End: rowStart + COLUMN_COUNT - 1 - index,
  };
  if (!(event.key in steps)) return;

  event.preventDefault();
  const next =
    cells[Math.min(Math.max(index + steps[event.key], 0), cells.length - 1)];
  setActiveCell(cells, next);
  next.focus();
};

// The grid only exists once loading ends, so (re)attach whenever it appears
watch(gridRef, element => {
  observer?.disconnect();
  if (!element) return;
  observer = new MutationObserver(applyRovingTabindex);
  observer.observe(element, { childList: true, subtree: true });
  nextTick(applyRovingTabindex);
});
onBeforeUnmount(() => observer?.disconnect());

const colorSchemeClass = computed(() => {
  return props.colorScheme === 'green'
    ? '[--cw-viz-heatmap-focus-color:rgb(var(--teal-9))]'
    : '[--cw-viz-heatmap-focus-color:rgb(var(--blue-9))]';
});
</script>

<template>
  <div
    v-if="isLoading"
    class="grid relative w-full gap-x-4 gap-y-2.5 overflow-y-scroll md:overflow-visible grid-cols-[5rem_1fr]"
  >
    <div class="grid gap-[0.3125rem] flex-shrink-0">
      <div
        v-for="ii in numberOfRows"
        :key="ii"
        class="w-full rounded-sm bg-n-slate-3 dark:bg-n-slate-1 animate-loader-pulse h-8 min-w-[4.375rem]"
      />
    </div>
    <div class="grid gap-[0.3125rem] w-full min-w-[43.75rem]">
      <div
        v-for="ii in numberOfRows"
        :key="ii"
        class="grid gap-[0.3125rem] grid-cols-[repeat(24,_1fr)]"
      >
        <div
          v-for="jj in 24"
          :key="jj"
          class="w-full h-8 rounded-sm bg-n-slate-3 dark:bg-n-slate-1 animate-loader-pulse"
        />
      </div>
    </div>
    <div />
    <div
      class="grid grid-cols-[repeat(24,_1fr)] gap-[0.3125rem] w-full text-xxxs font-semibold h-5 text-n-slate-11"
    >
      <div v-for="ii in 24" :key="ii" class="flex items-center justify-center">
        {{ ii - 1 }}
      </div>
    </div>
  </div>
  <!-- Custom (MyDesk): 12px labels (10–11px upstream), an hour label every 3 hours, one tab stop -->
  <div v-else ref="gridRef" @keydown="onGridKeydown">
    <HeatmapChart
      :data="chartData"
      :aria-label="ariaLabel"
      :colors="heatmapColors"
      :format-value="formatValue"
      :quantiles="QUANTILES"
      :cell-min-width="24"
      :gap="5"
      :row-label-width="96"
      zero-color="rgb(var(--solid-2))"
      class="[--cw-viz-heatmap-level-0-color:rgb(var(--slate-2))] [--cw-viz-heatmap-cell-border-color:rgb(var(--border-strong))] [--cw-viz-heatmap-label-color:rgb(var(--slate-11))] [--cw-viz-heatmap-label-background:rgb(var(--solid-2))] [--cw-viz-heatmap-row-title-color:rgb(var(--slate-12))] [--cw-viz-heatmap-column-label-color:rgb(var(--slate-12))] [--cw-viz-heatmap-tooltip-border-color:rgb(var(--border-strong))] [--cw-viz-heatmap-tooltip-color:rgb(var(--slate-12))] [--cw-viz-heatmap-tooltip-background:rgb(var(--solid-2))] [--cw-viz-heatmap-tooltip-label-color:rgb(var(--slate-11))] [--cw-viz-heatmap-column-label-font-size:12px] [--cw-viz-heatmap-row-description-font-size:12px] [--cw-viz-heatmap-row-title-font-size:13px] [&_.cw-viz-heatmap\_\_column-label:not(:nth-child(3n+2))]:invisible"
      :class="colorSchemeClass"
    />
  </div>
</template>
