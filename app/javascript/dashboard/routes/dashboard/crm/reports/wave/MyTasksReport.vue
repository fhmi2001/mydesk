<script setup>
// Custom (MyDesk): التقرير 4, my overdue and due-today tasks, and what I finished (SalesCrm::Reports::MyTasks)
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useCrmFormat } from '../../shared/useCrmFormat';
import { deltaFor } from '../summaryDelta';
import NumberTile from './NumberTile.vue';
import ReportSection from './ReportSection.vue';

const props = defineProps({
  data: { type: Object, required: true },
});

const emit = defineEmits(['drill']);

// The page hands every report its currency; tasks have none
defineOptions({ inheritAttrs: false });

const { t } = useI18n();
const { number, dateTime } = useCrmFormat();
const L = key => t(`CRM.REPORTS.WAVE.TASKS.${key}`);
const drill = (cell, title) => emit('drill', cell, title);

const kinds = computed(() =>
  Object.entries(props.data.totals.by_kind).filter(([, count]) => count)
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
      <NumberTile
        :label="L('OVERDUE')"
        :value="number(data.totals.overdue_count)"
        :tone="data.totals.overdue_count ? 'bad' : ''"
        :cell="{ kind: 'overdue' }"
        @drill="drill"
      />
      <NumberTile
        :label="L('TODAY')"
        :value="number(data.totals.today_count)"
        :cell="{ kind: 'today' }"
        @drill="drill"
      />
      <NumberTile
        :label="L('DONE')"
        :value="number(data.totals.done_count)"
        :delta="
          deltaFor(data.totals.done_count, data.previous_totals.done_count)
        "
        :cell="{ kind: 'done' }"
        @drill="drill"
      />
    </div>

    <p
      v-if="kinds.length"
      class="flex flex-wrap gap-x-4 gap-y-1 text-label-small text-n-slate-11"
    >
      <span v-for="[kind, count] in kinds" :key="kind">
        {{ t(`CRM.TASKS.KINDS.${kind}`) }}:
        <span class="tabular-nums text-n-slate-12">{{ number(count) }}</span>
      </span>
    </p>

    <ReportSection :title="L('LIST')">
      <ul v-if="data.rows.length" class="divide-y divide-n-weak">
        <li
          v-for="task in data.rows"
          :key="task.id"
          class="flex flex-wrap items-baseline justify-between gap-2 py-2.5 text-body-main"
        >
          <div class="min-w-0">
            <router-link
              :to="{ name: 'crm_task', params: { taskId: task.id } }"
              class="text-n-slate-12 hover:text-n-brand hover:underline"
            >
              {{ task.title }}
            </router-link>
            <p class="text-label-small text-n-slate-10">
              {{ t(`CRM.TASKS.KINDS.${task.kind}`) }}
              <template v-if="task.deal">
                ·
                <router-link
                  :to="{ name: 'crm_deal', params: { dealId: task.deal.id } }"
                  class="hover:text-n-brand hover:underline"
                >
                  {{ task.deal.title }}
                </router-link>
              </template>
              <template v-if="task.contact">
                · {{ task.contact.name }}
              </template>
            </p>
          </div>
          <span
            class="text-label-small tabular-nums shrink-0"
            :class="
              task.overdue ? 'text-n-ruby-11 font-medium' : 'text-n-slate-11'
            "
          >
            {{ dateTime(task.due_at) }}
          </span>
        </li>
      </ul>
      <p v-else class="text-body-main text-n-slate-11">{{ L('NONE_OPEN') }}</p>
      <router-link
        :to="{ name: 'crm_tasks' }"
        data-print-hide
        class="inline-block mt-4 text-label-small text-n-brand hover:underline"
      >
        {{ L('ALL_TASKS') }}
      </router-link>
    </ReportSection>
  </div>
</template>
