<script setup>
// Custom (MyDesk): each employee's attainment of this month's target, from the quota report (already best first; the
// page passes only the rows with a target)
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useCrmFormat } from '../crm/shared/useCrmFormat';

const props = defineProps({
  rows: { type: Array, required: true },
});

const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const { number } = useCrmFormat();

const bars = computed(() =>
  props.rows.map(row => ({
    id: row.assignee_id,
    name: row.name || t('CRM.COMMON.UNASSIGNED'),
    rate: `${number(row.attainment)}%`,
    width: `${Math.min(100, Math.max(0, row.attainment))}%`,
  }))
);
</script>

<template>
  <section
    class="relative p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak hover:bg-n-alpha-1"
  >
    <h2 class="mb-4 text-heading-3 text-n-slate-12">
      <router-link
        :to="accountScopedRoute('crm_report', { reportKey: 'quota' })"
        class="after:absolute after:inset-0 after:rounded-xl focus-visible:outline-none focus-visible:after:outline focus-visible:after:outline-2 focus-visible:after:outline-n-brand"
      >
        {{ t('HOME.TEAM') }}
      </router-link>
    </h2>
    <ul class="flex flex-col gap-3 m-0 list-none">
      <li
        v-for="bar in bars"
        :key="bar.id"
        class="grid items-center grid-cols-[7rem_1fr_3rem] gap-3"
      >
        <span class="truncate text-body-main text-n-slate-12">{{
          bar.name
        }}</span>
        <span class="h-2 overflow-hidden rounded-full bg-n-alpha-2">
          <span
            class="block h-full rounded-full bg-n-teal-9"
            :style="{ width: bar.width }"
          />
        </span>
        <span class="text-label-small text-end tabular-nums text-n-slate-11">
          {{ bar.rate }}
        </span>
      </li>
    </ul>
  </section>
</template>
