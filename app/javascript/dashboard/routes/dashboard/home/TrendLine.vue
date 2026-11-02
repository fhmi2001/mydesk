<script setup>
// Custom (MyDesk): one or two lines over a period (charts.js lineSegments), as the quota report draws its own: lines
// [{ id, label, values, color, dashed }], the dates at both ends, and a legend. A missing value leaves a gap (a lone
// point is a dot); `table` ({ headers, rows }) gives screen readers the values the picture shows. With `format`, the top
// of the scale shows above the line and each line's latest value beside its legend.
import { computed } from 'vue';
import { lineSegments } from './charts';

const props = defineProps({
  lines: { type: Array, required: true },
  max: { type: Number, required: true },
  start: { type: String, default: '' },
  end: { type: String, default: '' },
  ariaLabel: { type: String, required: true },
  table: { type: Object, required: true },
  format: { type: Function, default: null },
});

const W = 300;
const H = 100;

const latest = line => {
  const known = line.values.filter(v => v !== null && v !== undefined);
  return known.length ? props.format(known.at(-1)) : '';
};

const drawn = computed(() =>
  props.lines.flatMap(line =>
    lineSegments(line.values, { width: W, height: H, max: props.max }).map(
      (points, i) => ({
        key: `${line.id}-${i}`,
        line,
        points,
        dot: points.includes(' ') ? null : points.split(',').map(Number),
      })
    )
  )
);
</script>

<template>
  <div>
    <div v-if="format" dir="ltr" aria-hidden="true" class="flex">
      <span
        data-testid="trend-max"
        class="text-label-small tabular-nums text-n-slate-11"
        dir="auto"
      >
        {{ format(max) }}
      </span>
    </div>
    <svg
      :viewBox="`0 -6 ${W} ${H + 12}`"
      class="w-full h-36"
      preserveAspectRatio="none"
      aria-hidden="true"
    >
      <!-- The top of the scale -->
      <line
        v-if="format"
        x1="0"
        :x2="W"
        y1="0"
        y2="0"
        stroke="rgb(var(--slate-6))"
        stroke-dasharray="2 4"
        vector-effect="non-scaling-stroke"
      />
      <template v-for="segment in drawn" :key="segment.key">
        <circle
          v-if="segment.dot"
          :cx="segment.dot[0]"
          :cy="segment.dot[1]"
          r="3"
          :fill="segment.line.color"
          vector-effect="non-scaling-stroke"
        />
        <polyline
          v-else
          :points="segment.points"
          fill="none"
          :stroke="segment.line.color"
          :stroke-width="segment.line.dashed ? 2 : 2.5"
          :stroke-dasharray="segment.line.dashed ? '6 5' : undefined"
          vector-effect="non-scaling-stroke"
        />
      </template>
    </svg>
    <table class="sr-only">
      <caption>
        {{
          ariaLabel
        }}
      </caption>
      <thead>
        <tr>
          <th v-for="header in table.headers" :key="header" scope="col">
            {{ header }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(row, i) in table.rows" :key="i">
          <td v-for="(cell, j) in row" :key="j">{{ cell }}</td>
        </tr>
      </tbody>
    </table>
    <!-- The line runs left to right in time (as the bar charts do), in RTL too: its dates follow it -->
    <div
      data-testid="trend-axis"
      dir="ltr"
      class="flex flex-wrap items-center justify-between gap-3 mt-2 text-label-small text-n-slate-11"
      aria-hidden="true"
    >
      <span class="tabular-nums" dir="auto">{{ start }}</span>
      <span class="flex flex-wrap gap-3">
        <span
          v-for="line in lines"
          :key="line.id"
          dir="auto"
          class="flex items-center gap-1"
        >
          <span
            class="inline-block w-3 h-0.5"
            :style="{ background: line.color }"
          />
          {{ line.label }}
          <bdi v-if="format && latest(line)" class="tabular-nums">
            {{ `· ${latest(line)}` }}
          </bdi>
        </span>
      </span>
      <span class="tabular-nums" dir="auto">{{ end }}</span>
    </div>
  </div>
</template>
