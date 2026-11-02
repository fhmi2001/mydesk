<script setup>
// Custom (MyDesk): the home screen (docs/superpowers/specs/2026-11-01-home-screen-design.md). The employee sees what is
// waiting for them now, ranked by urgency; the manager sees what needs stepping in, with today's support numbers and
// the month's sales beside it. Sales parts show only when the account has the Sales CRM on.
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import NumberTile from '../crm/reports/wave/NumberTile.vue';
import { findLeak } from '../crm/reports/wave/leak';
import { compareKpi } from './kpi';
import { useCrmFormat } from '../crm/shared/useCrmFormat';
import ActionBar from './ActionBar.vue';
import AttentionList from './AttentionList.vue';
import TeamBars from './TeamBars.vue';
import HomeCharts from './HomeCharts.vue';
import { loadAgentHome, loadManagerHome } from './homeData';
import { agentItems, managerItems, agentTargetRate } from './attention';

const { t } = useI18n();
const store = useStore();
const { isAdmin } = useAdmin();
const crmEnabled = useMapGetter('crm/status/isEnabled');
const crmFlags = useMapGetter('crm/status/getUIFlags');
const currentUser = useMapGetter('getCurrentUser');
const { number, money, compactMoney, plural } = useCrmFormat();

const data = ref(null);
const isLoading = ref(true);

const load = async () => {
  isLoading.value = true;
  const loader = isAdmin.value ? loadManagerHome : loadAgentHome;
  data.value = await loader({ crmEnabled: Boolean(crmEnabled.value) });
  isLoading.value = false;
};

onMounted(async () => {
  // Whether the sales parts show: wait to know
  if (!crmFlags.value?.hasFetched)
    await store.dispatch('crm/status/fetch').catch(() => {});
  load();
});

const firstName = computed(() => (currentUser.value?.name || '').split(' ')[0]);
const greeting = computed(() =>
  new Date().getHours() < 12
    ? t('HOME.MORNING', { name: firstName.value })
    : t('HOME.EVENING', { name: firstName.value })
);

const d = key => data.value?.[key];
const payload = key => d(key)?.data?.payload || [];
const meta = computed(() => d('meta')?.meta || {});
const currency = computed(
  () => d('quota')?.currency || d('forecast')?.currency || 'SAR'
);
const percent = value =>
  value === null || value === undefined ? '—' : `${number(value)}%`;
const LOAD_FAILED = t('HOME.LOAD_FAILED');

// The list's sources: when one failed the list says so, rather than looking like nothing waits
const LIST_SOURCES = {
  manager: {
    support: ['meta', 'waiting'],
    sales: ['conversion', 'stale', 'lateTasks'],
  },
  agent: { support: ['conversations'], sales: ['tasks', 'deals'] },
};
const listSources = computed(() => {
  const sources = LIST_SOURCES[isAdmin.value ? 'manager' : 'agent'];
  return [...sources.support, ...(crmEnabled.value ? sources.sales : [])];
});
const listFailed = computed(() => listSources.value.some(key => !d(key)));

// «ينتظرك الآن» (the deals report already holds only the next 7 days)
const items = computed(() =>
  agentItems({
    conversations: payload('conversations'),
    tasks: d('tasks')?.rows || [],
    deals: (d('deals')?.rows || []).filter(deal => deal.close_date),
  })
);
const targetRate = computed(() => agentTargetRate(d('quota')));

// «يحتاج تدخّلك»
const lines = computed(() => {
  const leak = findLeak(d('conversion'));
  const stale = d('stale')?.totals?.at_risk;
  const tasks = d('lateTasks');
  const byName = (tasks?.tasks || []).reduce((acc, task) => {
    const name = task.assignee?.name;
    if (name) acc[name] = (acc[name] || 0) + 1;
    return acc;
  }, {});
  const [topName, topCount] =
    Object.entries(byName).sort((a, b) => b[1] - a[1])[0] || [];
  return managerItems({
    unassigned: d('meta') ? { count: meta.value.unassigned_count } : null,
    // Counted on the server (HomeController#waiting)
    waitingLong: d('waiting') ? { count: d('waiting').late_count } : null,
    leak: leak ? { name: leak.name, rate: leak.rate } : null,
    stale: stale ? { count: stale.count, amount: stale.total_cents } : null,
    lateTasks: tasks ? { count: tasks.total, topName, topCount } : null,
  });
});

// The employees with a target this month (the quota report ranks them best first)
const teamRows = computed(() =>
  (d('quota')?.assignees || []).filter(
    row => row.attainment !== null && row.attainment !== undefined
  )
);

const count = computed(() =>
  isAdmin.value ? lines.value.length : items.value.length
);

const satisfaction = computed(() => {
  const csat = d('csat');
  if (!csat) return LOAD_FAILED;
  const ratings = csat.ratings_count || {};
  const happy = (ratings[4] || 0) + (ratings[5] || 0);
  return csat.total_count
    ? percent(Math.round((happy * 100) / csat.total_count))
    : '—';
});

// The numbers strip, every number of the screen in one place: today against yesterday up to the same hour, the month
// against last month up to the same day (kpi.js)
const duration = seconds => {
  if (!seconds) return '—';
  return seconds < 3600
    ? t('HOME.MINUTES', { count: number(Math.round(seconds / 60)) })
    : t('HOME.HOURS', { count: number(Math.round(seconds / 360) / 10) });
};
// average: an average (a time) rather than a count; a slower one is worse
const summaryKpi = (key, label, format, average = false) => {
  const summary = d('summary');
  if (!summary) return { key, label, value: LOAD_FAILED };
  const current = Number(summary[key]) || 0;
  const soFar = d('summarySoFar');
  return {
    key,
    label,
    value: format(current),
    delta: soFar
      ? compareKpi(current, Number(soFar[key]) || 0, {
          average,
          lowerIsBetter: average,
        })
      : null,
  };
};
const salesKpis = () => {
  const quota = d('quota');
  const pipeline = d('pipeline');
  const forecast = d('forecast');
  const teamTarget = {
    key: 'team_target',
    label: t('HOME.TILES.TEAM_TARGET'),
    value: quota ? percent(quota.totals.attainment) : LOAD_FAILED,
    note: forecast
      ? t('HOME.TILES.FORECAST', {
          rate: percent(forecast.totals.forecast_attainment),
          amount: money(forecast.totals.forecast_cents, currency.value),
        })
      : '',
  };
  return [
    ...(isAdmin.value ? [teamTarget] : []),
    {
      key: 'sales',
      label: isAdmin.value ? t('HOME.KPI.SALES') : t('HOME.KPI.MY_SALES'),
      value: quota
        ? compactMoney(quota.totals.won_cents, currency.value)
        : LOAD_FAILED,
      delta:
        quota && d('quotaSoFar')
          ? compareKpi(quota.totals.won_cents, d('quotaSoFar').totals.won_cents)
          : null,
    },
    {
      key: 'pipeline',
      label: isAdmin.value ? t('HOME.KPI.PIPELINE') : t('HOME.KPI.MY_PIPELINE'),
      value: pipeline
        ? compactMoney(pipeline.totals.total_cents, currency.value)
        : LOAD_FAILED,
      note: pipeline ? plural('CRM.PLURALS.DEALS', pipeline.totals.count) : '',
    },
  ];
};
const managerSupportKpis = () => [
  {
    key: 'open',
    label: t('HOME.TILES.OPEN'),
    value: d('meta') ? number(meta.value.all_count) : LOAD_FAILED,
  },
  summaryKpi('conversations_count', t('HOME.KPI.NEW_TODAY'), number),
  summaryKpi('resolutions_count', t('HOME.KPI.RESOLVED_TODAY'), number),
  summaryKpi(
    'avg_first_response_time',
    t('HOME.TILES.FIRST_RESPONSE'),
    duration,
    true
  ),
  summaryKpi(
    'avg_resolution_time',
    t('HOME.KPI.RESOLUTION_TIME'),
    duration,
    true
  ),
  { key: 'csat', label: t('HOME.TILES.CSAT'), value: satisfaction.value },
];
const agentKpis = () => {
  const tasks = d('tasks');
  return [
    {
      key: 'mine',
      label: t('HOME.TILES.MY_OPEN'),
      value: d('meta') ? number(meta.value.mine_count) : LOAD_FAILED,
    },
    ...(crmEnabled.value
      ? [
          {
            key: 'tasks',
            label: t('HOME.TILES.TASKS_TODAY'),
            value: tasks ? number(tasks.totals.today_count) : LOAD_FAILED,
            note: tasks?.totals.overdue_count
              ? t('HOME.TILES.LATE', {
                  count: number(tasks.totals.overdue_count),
                })
              : '',
            tone: tasks?.totals.overdue_count ? 'bad' : '',
          },
          ...(targetRate.value === null
            ? []
            : [
                {
                  key: 'target',
                  label: t('HOME.TILES.MY_TARGET'),
                  value: percent(targetRate.value),
                },
              ]),
          ...salesKpis(),
        ]
      : []),
  ];
};
// [{ key, title, tiles }]: the manager's support and sales groups, the employee's one
const kpiGroups = computed(() => {
  if (!isAdmin.value) return [{ key: 'mine', title: '', tiles: agentKpis() }];
  return [
    {
      key: 'support',
      title: t('HOME.SUPPORT_TODAY'),
      tiles: managerSupportKpis(),
    },
    ...(crmEnabled.value
      ? [{ key: 'sales', title: t('HOME.SALES_MONTH'), tiles: salesKpis() }]
      : []),
  ];
});
</script>

<template>
  <!-- below md the menu button floats over the bottom: the page scrolls clear of it -->
  <div
    class="flex flex-col flex-1 w-full h-full min-w-0 pb-20 overflow-y-auto md:pb-0"
  >
    <header class="flex flex-col gap-4 px-6 pt-6 pb-5">
      <div>
        <h1 class="text-heading-1 text-n-slate-12">{{ greeting }}</h1>
        <p
          v-if="!isLoading && !listFailed"
          class="mt-1 text-body-main text-n-slate-11"
        >
          {{
            isAdmin
              ? plural('HOME.NEEDS_YOU_COUNT', count)
              : plural('HOME.WAITING_COUNT', count)
          }}
        </p>
      </div>
      <ActionBar :crm-enabled="Boolean(crmEnabled)" :is-admin="isAdmin" />
    </header>

    <div v-if="isLoading" class="flex items-center justify-center flex-1 py-16">
      <Spinner />
    </div>

    <!-- The numbers strip: every number of the screen, in groups -->
    <div
      v-if="!isLoading"
      data-testid="home-kpis"
      class="flex flex-col gap-4 px-6 pb-4"
    >
      <section
        v-for="group in kpiGroups"
        :key="group.key"
        :aria-label="group.title || undefined"
      >
        <h2 v-if="group.title" class="mb-2 text-label-small text-n-slate-11">
          {{ group.title }}
        </h2>
        <div class="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
          <NumberTile
            v-for="kpi in group.tiles"
            :key="kpi.key"
            :label="kpi.label"
            :value="kpi.value"
            :note="kpi.note || ''"
            :delta="kpi.delta || null"
            :tone="kpi.tone || ''"
          />
        </div>
      </section>
    </div>

    <!-- The list, beside the team's bars when there are any -->
    <div
      v-if="!isLoading"
      class="grid items-start gap-4 px-6 pb-4"
      :class="{
        'lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]':
          isAdmin && crmEnabled && teamRows.length,
      }"
    >
      <AttentionList
        :title="isAdmin ? t('HOME.NEEDS_YOU') : t('HOME.WAITING_FOR_YOU')"
        :items="isAdmin ? lines : items"
        :currency="currency"
        :failed="listFailed"
      />
      <TeamBars
        v-if="isAdmin && crmEnabled && teamRows.length"
        :rows="teamRows"
      />
    </div>

    <HomeCharts
      v-if="!isLoading"
      class="px-6 pb-8"
      :data="data || {}"
      :is-admin="isAdmin"
      :crm-enabled="Boolean(crmEnabled)"
      :currency="currency"
    />
  </div>
</template>
