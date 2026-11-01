<script setup>
// Custom (MyDesk): التقرير 9, where deals leak between stages (SalesCrm::Reports::Conversion)
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';
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
const L = (key, args) => t(`CRM.REPORTS.WAVE.CONVERSION.${key}`, args);
const drill = (cell, title) => emit('drill', cell, title);

const top = computed(() => Math.max(1, props.data.rows[0]?.count || 0));
const percent = value => (value === null ? '—' : `${number(value)}%`);
const leak = computed(() =>
  props.data.rows.find(r => r.stage_id === props.data.leak_stage_id)
);
const stageName = id => props.data.rows.find(r => r.stage_id === id)?.name;
// Each employee's rate beside the team's: better in green, worse in red
const tone = stage => {
  if (stage.rate === null || stage.team_rate === null) return 'text-n-slate-11';
  if (stage.rate === stage.team_rate) return 'text-n-slate-12';
  return stage.rate > stage.team_rate ? 'text-n-teal-11' : 'text-n-ruby-11';
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <p class="text-body-main text-n-slate-11">
      {{
        L('SCOPE', {
          count: number(data.created_count),
          pipeline: data.pipeline_name,
        })
      }}
      <template v-if="leak">
        <span class="font-medium text-n-ruby-11">
          {{ L('LEAK', { stage: leak.name, rate: percent(leak.rate) }) }}
        </span>
      </template>
    </p>

    <ReportSection :title="L('FUNNEL')" :note="L('SKIPPED')">
      <ol class="flex flex-col gap-3">
        <li
          v-for="row in data.rows"
          :key="row.stage_id"
          class="grid items-center grid-cols-[9rem_1fr_auto] gap-3 text-body-main"
        >
          <span class="flex items-center gap-2 truncate text-n-slate-12">
            <span
              class="rounded-full size-2 shrink-0"
              :style="{ backgroundColor: row.color }"
              aria-hidden="true"
            />
            {{ row.name }}
          </span>
          <div class="h-3 rounded-full bg-n-slate-3" aria-hidden="true">
            <div
              class="h-full rounded-full"
              :class="
                row.stage_id === data.leak_stage_id
                  ? 'bg-n-ruby-9'
                  : 'bg-n-iris-9'
              "
              :style="{ width: `${(row.count / top) * 100}%` }"
            />
          </div>
          <span class="flex items-baseline gap-2 text-n-slate-11">
            <CellButton
              :cell="row.cell"
              :label="number(row.count)"
              :title="row.name"
              :empty="!row.count"
              @drill="drill"
            />
            <span
              v-if="row.rate !== null"
              class="text-label-small tabular-nums"
              :class="{
                'text-n-ruby-11 font-medium':
                  row.stage_id === data.leak_stage_id,
              }"
            >
              {{ L('RATE', { rate: percent(row.rate) }) }}
            </span>
          </span>
        </li>
      </ol>
    </ReportSection>

    <ReportSection
      v-if="data.assignees?.length"
      :title="L('BY_ASSIGNEE')"
      :note="L('VS_TEAM')"
    >
      <div class="overflow-x-auto">
        <table class="w-full text-body-main">
          <thead>
            <tr class="text-label-small text-n-slate-11">
              <th scope="col" class="py-2 font-medium text-start">
                {{ t('CRM.REPORTS.AGENTS.AGENT') }}
              </th>
              <th scope="col" class="py-2 ps-3 font-medium text-end">
                {{ L('CREATED') }}
              </th>
              <th
                v-for="row in data.rows.slice(1)"
                :key="row.stage_id"
                scope="col"
                class="py-2 ps-3 font-medium text-end"
              >
                {{ stageName(row.stage_id) }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-n-weak">
            <tr
              v-for="person in data.assignees"
              :key="person.assignee_id ?? 'none'"
            >
              <th
                scope="row"
                class="py-2.5 font-normal text-start text-n-slate-12"
              >
                {{ person.name || t('CRM.COMMON.UNASSIGNED') }}
              </th>
              <td class="py-2.5 ps-3 text-end tabular-nums">
                {{ number(person.created_count) }}
              </td>
              <td
                v-for="stage in person.stages.slice(1)"
                :key="stage.stage_id"
                class="py-2.5 ps-3 text-end tabular-nums"
                :class="tone(stage)"
              >
                <CellButton
                  :cell="stage.cell"
                  :label="percent(stage.rate)"
                  :title="`${person.name} · ${stageName(stage.stage_id)}`"
                  :empty="!stage.count"
                  @drill="drill"
                />
                <span class="block text-label-small text-n-slate-11">
                  {{ L('TEAM', { rate: percent(stage.team_rate) }) }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </ReportSection>
  </div>
</template>
