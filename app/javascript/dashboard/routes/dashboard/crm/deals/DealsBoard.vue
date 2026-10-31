<script setup>
// Custom (MyDesk): the kanban board: a column per stage, cards draggable between and within columns.
// On touch a short press starts the drag, so a swipe still scrolls the board. Keyboard users change a deal's
// stage from its page (stage picker), since dragging has no keyboard equivalent here.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import DealCard from './DealCard.vue';
import { useCrmFormat } from '../shared/useCrmFormat';

const props = defineProps({
  pipeline: { type: Object, required: true },
  dealsForStage: { type: Function, required: true },
  counts: { type: Object, default: () => ({}) },
  loadingStageId: { type: [Number, String], default: null },
});
const emit = defineEmits(['move', 'open', 'add', 'loadMore']);
const { t } = useI18n();
const { money, number } = useCrmFormat();

// Touch: hold 180ms before a card lifts; mouse drags start at once. The options go in as an object because
// `delayOnTouchOnly` needs a real `true`: a bare `delay-on-touch-only` attribute (what the lint rule asks
// for) reaches Sortable as "" (false), which gave the mouse the delay too. With native drag Sortable fixes the
// move tolerance during the hold at 1px, so a finger that moves scrolls the board instead.
const DRAG_OPTIONS = { delay: 180, delayOnTouchOnly: true };

const columns = computed(() =>
  props.pipeline.stages.map(stage => ({
    stage,
    deals: props.dealsForStage(stage.id),
    count: props.counts[stage.id]?.count || 0,
    total: props.counts[stage.id]?.total_cents || 0,
  }))
);

// vuedraggable gives the new list; we only care about which card landed where
const onChange = (stage, event) => {
  const moved = event.added || event.moved;
  if (!moved) return;
  emit('move', {
    dealId: moved.element.id,
    stageId: stage.id,
    position: moved.newIndex,
    stage,
  });
};

const remaining = column => column.count - column.deals.length;
// What the column is worth at its stage's win probability, rounded to the minor unit
const weighted = column =>
  Math.round((column.total * (column.stage.probability || 0)) / 100);
</script>

<template>
  <div class="flex-1 min-h-0 px-6 pb-6 overflow-x-auto overflow-y-hidden">
    <div
      class="flex h-full gap-4"
      :style="{ minWidth: `${columns.length * 18}rem` }"
    >
      <section
        v-for="column in columns"
        :key="column.stage.id"
        class="flex flex-col h-full w-72 shrink-0 rounded-xl bg-n-slate-2 outline outline-1 -outline-offset-1 outline-n-weak"
        :data-stage-id="column.stage.id"
        :aria-labelledby="`crm-stage-${column.stage.id}`"
      >
        <header class="px-4 pt-3 pb-2 border-b border-n-weak">
          <div class="flex items-center justify-between gap-2">
            <h2
              :id="`crm-stage-${column.stage.id}`"
              class="flex items-center gap-2 truncate text-heading-3 text-n-slate-12"
            >
              <span
                class="size-2.5 rounded-full shrink-0"
                :style="{ backgroundColor: column.stage.color }"
                aria-hidden="true"
              />
              <span class="truncate">{{ column.stage.name }}</span>
            </h2>
            <span
              class="px-2 py-0.5 rounded-full text-label-small bg-n-solid-1 text-n-slate-11 tabular-nums"
            >
              {{ number(column.count) }}
            </span>
          </div>
        </header>

        <Draggable
          :list="column.deals"
          item-key="id"
          group="crm-deals"
          class="flex flex-col flex-1 gap-2 p-3 overflow-y-auto min-h-16"
          ghost-class="opacity-40"
          :animation="150"
          v-bind="DRAG_OPTIONS"
          @change="onChange(column.stage, $event)"
        >
          <template #item="{ element }">
            <DealCard :deal="element" @open="emit('open', $event)" />
          </template>
          <template #footer>
            <button
              v-if="remaining(column) > 0"
              type="button"
              class="w-full py-2 rounded-lg text-label-small text-n-blue-11 hover:bg-n-alpha-2 disabled:opacity-60"
              :disabled="loadingStageId === column.stage.id"
              @click="emit('loadMore', column.stage)"
            >
              {{ t('CRM.COMMON.SHOW_MORE') }} ({{ number(remaining(column)) }})
            </button>
            <button
              v-if="column.stage.kind === 'open'"
              type="button"
              class="flex items-center justify-center w-full gap-1 py-2 rounded-lg text-body-main text-n-slate-11 outline outline-1 -outline-offset-1 outline-dashed outline-n-strong hover:text-n-slate-12"
              @click="emit('add', column.stage)"
            >
              <span class="i-lucide-plus size-4" aria-hidden="true" />
              {{ t('CRM.DEALS.ADD_TO_STAGE') }}
            </button>
          </template>
        </Draggable>

        <!-- The column's numbers stay pinned under its cards: the total, then what it is worth at the
             stage's win probability (won counts in full, lost counts for nothing) -->
        <footer
          class="px-4 py-2.5 border-t border-n-weak text-label-small text-n-slate-11 tabular-nums"
        >
          <dl class="flex flex-col gap-1">
            <div class="flex items-center justify-between gap-2">
              <dt>{{ t('CRM.DEALS.COLUMN_TOTAL') }}</dt>
              <dd class="font-medium text-n-slate-12" dir="auto">
                {{ money(column.total, pipeline.currency) }}
              </dd>
            </div>
            <div
              v-if="column.stage.kind === 'open'"
              class="flex items-center justify-between gap-2"
            >
              <dt class="inline-flex items-center gap-1">
                {{
                  t('CRM.DEALS.COLUMN_WEIGHTED', {
                    probability: column.stage.probability,
                  })
                }}
                <span
                  class="i-lucide-info size-3 text-n-slate-10"
                  :title="t('CRM.DEALS.COLUMN_WEIGHTED_HINT')"
                  aria-hidden="true"
                />
                <span class="sr-only">
                  {{ t('CRM.DEALS.COLUMN_WEIGHTED_HINT') }}
                </span>
              </dt>
              <dd class="font-medium text-n-slate-12" dir="auto">
                {{ money(weighted(column), pipeline.currency) }}
              </dd>
            </div>
            <div v-else class="flex items-center justify-between gap-2">
              <dt>{{ t('CRM.DEALS.COLUMN_OUTCOME') }}</dt>
              <dd>
                {{
                  column.stage.kind === 'won'
                    ? t('CRM.DEALS.COLUMN_WON')
                    : t('CRM.DEALS.COLUMN_LOST')
                }}
              </dd>
            </div>
          </dl>
        </footer>
      </section>
    </div>
  </div>
</template>
