<script setup>
// Custom (MyDesk): التقرير 1, open deals by stage (SalesCrm::Reports::PipelineByStage)
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';
import NumberTile from './NumberTile.vue';
import CellButton from './CellButton.vue';
import ReportSection from './ReportSection.vue';
import AssigneeTable from './AssigneeTable.vue';

const props = defineProps({
  data: { type: Object, required: true },
  currency: { type: String, default: 'SAR' },
});
const emit = defineEmits(['drill']);

const { t } = useI18n();
const { money, number } = useCrmFormat();
const L = key => t(`CRM.REPORTS.WAVE.PIPELINE.${key}`);

const maxValue = computed(() =>
  Math.max(1, ...props.data.rows.map(row => row.total_cents))
);
const showPipeline = computed(
  () => new Set(props.data.rows.map(row => row.pipeline_id)).size > 1
);
const assigneeColumns = computed(() => [
  { key: 'count', label: L('COUNT'), format: 'count', cell: row => row.cell },
  { key: 'total_cents', label: L('VALUE'), format: 'money' },
  { key: 'weighted_cents', label: L('WEIGHTED'), format: 'money' },
]);
const drill = (cell, title) => emit('drill', cell, title);
const unassigned = name => name || t('CRM.COMMON.UNASSIGNED');
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
      <NumberTile
        :label="L('COUNT')"
        :value="number(data.totals.count)"
        :cell="{}"
        @drill="drill"
      />
      <NumberTile
        :label="L('VALUE')"
        :value="money(data.totals.total_cents, currency)"
        :cell="{}"
        @drill="drill"
      />
      <NumberTile
        :label="L('WEIGHTED')"
        :value="money(data.totals.weighted_cents, currency)"
        :note="L('WEIGHTED_NOTE')"
      />
    </div>

    <ReportSection :title="L('BY_STAGE')">
      <div class="overflow-x-auto">
        <table class="w-full text-body-main">
          <thead>
            <tr class="text-label-small text-n-slate-11">
              <th scope="col" class="py-2 font-medium text-start">
                {{ L('STAGE') }}
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
            <tr v-for="row in data.rows" :key="row.stage_id" class="align-top">
              <th scope="row" class="py-3 pe-4 font-normal text-start">
                <span class="flex items-center gap-2 text-n-slate-12">
                  <span
                    class="rounded-full size-2 shrink-0"
                    :style="{ backgroundColor: row.color }"
                    aria-hidden="true"
                  />
                  {{ row.name }}
                  <span class="text-label-small text-n-slate-10">
                    {{ `${row.probability}%` }}
                  </span>
                </span>
                <span
                  v-if="showPipeline"
                  class="block text-label-small text-n-slate-10"
                >
                  {{ row.pipeline_name }}
                </span>
                <div
                  class="h-1.5 mt-2 rounded-full bg-n-slate-3 max-w-64"
                  aria-hidden="true"
                >
                  <div
                    class="h-full rounded-full"
                    :style="{
                      width: `${(row.total_cents / maxValue) * 100}%`,
                      backgroundColor: row.color,
                    }"
                  />
                </div>
                <ul
                  v-if="row.assignees?.length"
                  class="flex flex-wrap gap-x-3 gap-y-1 mt-2 text-label-small text-n-slate-11"
                >
                  <li v-for="person in row.assignees" :key="person.assignee_id">
                    {{ unassigned(person.name) }}
                    <CellButton
                      :cell="person.cell"
                      :label="number(person.count)"
                      :title="`${row.name} · ${unassigned(person.name)}`"
                      @drill="drill"
                    />
                  </li>
                </ul>
              </th>
              <td class="py-3 text-end">
                <CellButton
                  :cell="row.cell"
                  :label="number(row.count)"
                  :title="row.name"
                  :empty="!row.count"
                  @drill="drill"
                />
              </td>
              <td class="py-3 text-end tabular-nums" dir="auto">
                {{ money(row.total_cents, currency) }}
              </td>
              <td class="py-3 text-end tabular-nums text-n-slate-11" dir="auto">
                {{ money(row.weighted_cents, currency) }}
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
