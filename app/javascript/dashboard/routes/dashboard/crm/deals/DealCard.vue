<script setup>
// Custom (MyDesk): one deal on the board. Flat at rest (hairline outline, no shadow); the drag ghost and the
// focus ring are the only emphasis.
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
    class="w-full p-3 rounded-xl text-start bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak transition-[outline-color] hover:outline-n-strong focus-visible:outline-2 focus-visible:outline-n-brand cursor-grab active:cursor-grabbing"
    :data-deal-id="deal.id"
    @click="emit('open', deal)"
  >
    <p class="text-heading-3 text-n-slate-12 line-clamp-2">
      {{ deal.title }}
    </p>
    <p class="mt-1 text-heading-3 text-n-blue-11 tabular-nums" dir="auto">
      {{ amount }}
    </p>
    <div
      class="flex flex-wrap items-center gap-x-3 gap-y-1 mt-2 text-label-small text-n-slate-11"
    >
      <span
        v-if="deal.contact_name"
        class="inline-flex items-center gap-1 min-w-0"
      >
        <span class="i-lucide-user size-3 shrink-0" aria-hidden="true" />
        <span class="truncate">{{ deal.contact_name }}</span>
      </span>
      <span v-if="closeDate" class="inline-flex items-center gap-1">
        <span class="i-lucide-calendar size-3 shrink-0" aria-hidden="true" />
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
      <span class="text-label-small text-n-slate-11 truncate">
        {{ deal.assignee.name }}
      </span>
    </div>
  </button>
</template>
