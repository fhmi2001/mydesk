<script setup>
// Custom (MyDesk): the kanban board: a column per stage, cards draggable between and within columns
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import DealCard from './DealCard.vue';
import { useCrmFormat } from '../shared/useCrmFormat';

const props = defineProps({
  pipeline: { type: Object, required: true },
  dealsForStage: { type: Function, required: true },
  counts: { type: Object, default: () => ({}) },
});
const emit = defineEmits(['move', 'open', 'add', 'showMore']);
const { t } = useI18n();
const { compactMoney, number } = useCrmFormat();

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
</script>

<template>
  <div class="flex-1 min-h-0 overflow-x-auto overflow-y-hidden px-6 pb-6">
    <div
      class="flex h-full gap-4"
      :style="{ minWidth: `${columns.length * 18}rem` }"
    >
      <section
        v-for="column in columns"
        :key="column.stage.id"
        class="flex flex-col w-72 shrink-0 h-full rounded-2xl bg-n-slate-2 border border-n-weak"
        :data-stage-id="column.stage.id"
      >
        <header class="px-4 pt-3 pb-2 border-b border-n-weak">
          <div class="flex items-center justify-between gap-2">
            <h3
              class="flex items-center gap-2 text-sm font-semibold text-n-slate-12 truncate"
            >
              <span
                class="size-2.5 rounded-full shrink-0"
                :style="{ backgroundColor: column.stage.color }"
              />
              <span class="truncate">{{ column.stage.name }}</span>
            </h3>
            <span
              class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-solid-1 text-n-slate-11 tabular-nums"
            >
              {{ number(column.count) }}
            </span>
          </div>
          <p class="mt-1 text-xs text-n-slate-11 tabular-nums">
            <span>{{ column.stage.probability }}%</span>
            <span class="mx-1">·</span>
            <span dir="auto">{{
              column.total ? compactMoney(column.total, pipeline.currency) : '—'
            }}</span>
          </p>
        </header>

        <Draggable
          :list="column.deals"
          item-key="id"
          group="crm-deals"
          class="flex flex-col flex-1 min-h-16 gap-2 p-3 overflow-y-auto"
          ghost-class="opacity-40"
          :animation="150"
          @change="onChange(column.stage, $event)"
        >
          <template #item="{ element }">
            <DealCard :deal="element" @open="emit('open', $event)" />
          </template>
          <template #footer>
            <button
              v-if="column.count > column.deals.length"
              type="button"
              class="w-full py-2 text-xs text-n-slate-11 hover:text-n-slate-12"
              @click="emit('showMore', column.stage)"
            >
              {{ t('CRM.COMMON.SHOW_MORE') }} ({{
                number(column.count - column.deals.length)
              }})
            </button>
            <button
              v-if="column.stage.kind === 'open'"
              type="button"
              class="flex items-center justify-center w-full gap-1 py-2 text-sm rounded-lg border border-dashed border-n-strong text-n-slate-11 hover:text-n-slate-12 hover:border-n-slate-9"
              @click="emit('add', column.stage)"
            >
              <span class="i-lucide-plus size-4" />
              {{ t('CRM.DEALS.ADD_TO_STAGE') }}
            </button>
          </template>
        </Draggable>
      </section>
    </div>
  </div>
</template>
