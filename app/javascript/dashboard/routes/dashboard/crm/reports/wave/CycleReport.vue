<script setup>
// Custom (MyDesk): التقرير 11, how long deals take to close and where they wait (SalesCrm::Reports::Cycle). The heat
// map shades each employee's days in a stage against the slowest cell.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';
import { deltaFor } from '../summaryDelta';
import NumberTile from './NumberTile.vue';
import ReportSection from './ReportSection.vue';
import CellButton from './CellButton.vue';

const props = defineProps({
  data: { type: Object, required: true },
});
const emit = defineEmits(['drill']);
// The page hands every report its currency; this one counts deals and days only
defineOptions({ inheritAttrs: false });
const { t } = useI18n();
const { number } = useCrmFormat();
const L = (key, args) => t(`CRM.REPORTS.WAVE.CYCLE.${key}`, args);
const drill = (cell, title) => emit('drill', cell, title);

const days = value =>
  value === null || value === undefined
    ? '—'
    : L('DAYS', { days: number(value) });
const slowest = computed(() =>
  Math.max(
    1,
    ...props.data.stages.map(s => s.average_days || 0),
    ...(props.data.assignees || []).flatMap(a =>
      a.stages.map(s => s.average_days || 0)
    )
  )
);
const slowestStage = computed(
  () =>
    [...props.data.stages]
      .filter(s => s.average_days !== null)
      .sort((a, b) => b.average_days - a.average_days)[0]
);
// Shade: the share of the slowest, as the alpha of the warning colour
const heat = value =>
  value === null
    ? {}
    : {
        backgroundColor: `rgb(var(--amber-9) / ${0.12 + (value / slowest.value) * 0.6})`,
      };
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-3">
      <NumberTile
        :label="L('CYCLE')"
        :value="days(data.cycle_days)"
        :delta="deltaFor(data.cycle_days, data.previous_cycle_days, true)"
        :cell="{}"
        @drill="drill"
      />
      <NumberTile :label="L('WON')" :value="number(data.won_count)" />
      <NumberTile
        :label="L('SLOWEST')"
        :value="slowestStage ? slowestStage.name : '—'"
        :note="slowestStage ? days(slowestStage.average_days) : ''"
        tone="warn"
      />
    </div>
    <p
      v-if="data.approximate_count"
      class="-mt-3 text-label-small text-n-amber-11"
    >
      {{ L('APPROXIMATE', { count: number(data.approximate_count) }) }}
    </p>

    <ReportSection :title="L('BY_STAGE')" :note="L('WHAT_COUNTS')">
      <ol class="flex flex-col gap-3">
        <li
          v-for="stage in data.stages"
          :key="stage.stage_id"
          class="grid items-center grid-cols-[9rem_1fr_auto] gap-3 text-body-main"
        >
          <span class="truncate text-n-slate-12">{{ stage.name }}</span>
          <div class="h-3 rounded-full bg-n-slate-3" aria-hidden="true">
            <div
              class="h-full rounded-full bg-n-amber-9"
              :style="{
                width: `${((stage.average_days || 0) / slowest) * 100}%`,
              }"
            />
          </div>
          <span class="flex items-baseline gap-2 text-n-slate-11">
            <span class="tabular-nums text-n-slate-12">
              {{ days(stage.average_days) }}
            </span>
            <CellButton
              :cell="stage.cell"
              :label="L('STAYS', { count: number(stage.count) })"
              :title="stage.name"
              :empty="!stage.count"
              @drill="drill"
            />
          </span>
        </li>
      </ol>
    </ReportSection>

    <ReportSection v-if="data.assignees?.length" :title="L('HEAT')">
      <div class="overflow-x-auto">
        <table class="w-full text-body-main">
          <thead>
            <tr class="text-label-small text-n-slate-11">
              <th scope="col" class="py-2 font-medium text-start">
                {{ t('CRM.REPORTS.AGENTS.AGENT') }}
              </th>
              <th scope="col" class="py-2 ps-3 font-medium text-end">
                {{ L('CYCLE') }}
              </th>
              <th
                v-for="stage in data.stages"
                :key="stage.stage_id"
                scope="col"
                class="py-2 ps-3 font-medium text-center"
              >
                {{ stage.name }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="person in data.assignees"
              :key="person.assignee_id ?? 'none'"
            >
              <th
                scope="row"
                class="py-2 font-normal text-start text-n-slate-12"
              >
                {{ person.name || t('CRM.COMMON.UNASSIGNED') }}
              </th>
              <td class="py-2 ps-3 text-end tabular-nums">
                {{ days(person.cycle_days) }}
              </td>
              <td
                v-for="stage in person.stages"
                :key="stage.stage_id"
                class="p-1"
              >
                <div
                  class="px-2 py-1.5 text-center rounded-md tabular-nums"
                  :style="heat(stage.average_days)"
                >
                  <CellButton
                    :cell="stage.cell"
                    :label="days(stage.average_days)"
                    :title="`${person.name} · ${stage.name}`"
                    :empty="!stage.count"
                    @drill="drill"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </ReportSection>
  </div>
</template>
