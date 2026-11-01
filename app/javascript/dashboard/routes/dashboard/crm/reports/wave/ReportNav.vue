<script setup>
// Custom (MyDesk): the Sales reports' navigation: the dashboard, then the reports in their groups (reportCatalog.js),
// only those the user may open. A side list on wide screens; on a phone, one select that opens the report picked.
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { GROUPS, reportsFor } from './reportCatalog';

const props = defineProps({
  // the open report's key, or 'dashboard'
  current: { type: String, required: true },
});

const { t } = useI18n();
const router = useRouter();
const isAdmin = useMapGetter('crm/status/isAdmin');

const DASHBOARD = 'dashboard';
const groups = computed(() => {
  const mine = reportsFor(isAdmin.value);
  return GROUPS.map(group => ({
    group,
    reports: mine.filter(r => r.group === group),
  })).filter(g => g.reports.length);
});
const dashboardLabel = computed(() =>
  isAdmin.value
    ? t('CRM.REPORTS.WAVE.DASHBOARD.TEAM')
    : t('CRM.REPORTS.WAVE.DASHBOARD.MINE')
);
const reportName = key => t(`CRM.REPORTS.WAVE.REPORTS.${key}.NAME`);
const go = key =>
  router.push(
    key === DASHBOARD
      ? { name: 'crm_reports' }
      : { name: 'crm_report', params: { reportKey: key } }
  );
const linkClass = active =>
  active
    ? 'bg-n-alpha-2 text-n-slate-12 font-medium'
    : 'text-n-slate-11 hover:bg-n-alpha-1 hover:text-n-slate-12';
</script>

<template>
  <div>
    <!-- A phone: one select -->
    <label class="block px-4 pt-4 lg:hidden">
      <span class="sr-only">{{ t('CRM.REPORTS.WAVE.NAV') }}</span>
      <select
        class="w-full h-10 px-3 rounded-lg bg-n-solid-1 text-body-main text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak"
        :value="props.current"
        @change="go($event.target.value)"
      >
        <option :value="DASHBOARD">{{ dashboardLabel }}</option>
        <optgroup
          v-for="item in groups"
          :key="item.group"
          :label="t(`CRM.REPORTS.WAVE.GROUPS.${item.group}`)"
        >
          <option
            v-for="report in item.reports"
            :key="report.key"
            :value="report.key"
          >
            {{ reportName(report.key) }}
          </option>
        </optgroup>
      </select>
    </label>

    <!-- A wide screen: the side list -->
    <nav
      class="hidden h-full px-3 py-5 overflow-y-auto border-e border-n-weak lg:block w-60 shrink-0"
      :aria-label="t('CRM.REPORTS.WAVE.NAV')"
    >
      <router-link
        :to="{ name: 'crm_reports' }"
        class="flex items-center gap-2 px-3 py-2 mb-3 rounded-lg text-body-main"
        :class="linkClass(props.current === DASHBOARD)"
        :aria-current="props.current === DASHBOARD ? 'page' : undefined"
      >
        <span class="i-lucide-layout-dashboard size-4" aria-hidden="true" />
        {{ dashboardLabel }}
      </router-link>
      <div v-for="item in groups" :key="item.group" class="mb-3">
        <p class="px-3 mb-1 text-label-small text-n-slate-10">
          {{ t(`CRM.REPORTS.WAVE.GROUPS.${item.group}`) }}
        </p>
        <router-link
          v-for="report in item.reports"
          :key="report.key"
          :to="{ name: 'crm_report', params: { reportKey: report.key } }"
          class="flex items-center gap-2 px-3 py-1.5 rounded-lg text-label-small"
          :class="linkClass(report.key === props.current)"
          :aria-current="report.key === props.current ? 'page' : undefined"
        >
          <span
            :class="report.icon"
            class="size-4 shrink-0"
            aria-hidden="true"
          />
          <span class="truncate">{{ reportName(report.key) }}</span>
        </router-link>
      </div>
    </nav>
  </div>
</template>
