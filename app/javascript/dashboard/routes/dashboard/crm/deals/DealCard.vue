<script setup>
// Custom (MyDesk): one deal on the board
import { computed } from 'vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { useCrmFormat } from '../shared/useCrmFormat';

const props = defineProps({ deal: { type: Object, required: true } });
const emit = defineEmits(['open']);
const { money, date } = useCrmFormat();

const amount = computed(() =>
  money(props.deal.amount_cents, props.deal.currency)
);
const closeDate = computed(() =>
  props.deal.close_date ? date(props.deal.close_date) : ''
);
</script>

<template>
  <button
    type="button"
    class="w-full text-start rounded-xl border border-n-weak bg-n-solid-1 p-3 shadow-sm transition hover:border-n-strong hover:shadow focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-brand cursor-grab active:cursor-grabbing"
    :data-deal-id="deal.id"
    @click="emit('open', deal)"
  >
    <p class="text-sm font-medium leading-5 text-n-slate-12 line-clamp-2">
      {{ deal.title }}
    </p>
    <p class="mt-1 text-sm font-semibold text-n-brand tabular-nums" dir="auto">
      {{ amount }}
    </p>
    <div
      class="flex flex-wrap items-center gap-x-3 gap-y-1 mt-2 text-xs text-n-slate-11"
    >
      <span
        v-if="deal.contact_name"
        class="inline-flex items-center gap-1 min-w-0"
      >
        <span class="i-lucide-user size-3 shrink-0" />
        <span class="truncate">{{ deal.contact_name }}</span>
      </span>
      <span v-if="closeDate" class="inline-flex items-center gap-1">
        <span class="i-lucide-calendar size-3 shrink-0" />
        <span>{{ closeDate }}</span>
      </span>
    </div>
    <div v-if="deal.assignee" class="flex items-center gap-1.5 mt-2">
      <Avatar
        :name="deal.assignee.name"
        :src="deal.assignee.avatar_url"
        :size="18"
        rounded-full
      />
      <span class="text-xs text-n-slate-11 truncate">{{
        deal.assignee.name
      }}</span>
    </div>
  </button>
</template>
