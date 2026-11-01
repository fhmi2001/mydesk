<script setup>
// Custom (MyDesk): Sales > Reports, the first page (CRM_REPORTS_PLAN.md, phase 5). «لوحتي» for an employee: their
// pipeline, what closes this month, what went stale, their tasks, their target and forecast. «لوحة الفريق» for the
// manager: the team's attainment and ranking, forecast and coverage, the week's changes and what needs attention.
// Every number comes from a report of the catalog (the same request as its own page), opens its deals, and every
// card leads to its full report.
import { ref, computed, onMounted, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { crmReportsAPI } from 'dashboard/api/crm';
import CrmPageHeader from '../../shared/CrmPageHeader.vue';
import CrmUnavailable from '../../shared/CrmUnavailable.vue';
import { useCrmFormat } from '../../shared/useCrmFormat';
import { periodRange } from '../periods';
import { forwardRange } from './reportCatalog';
import { COLORS } from './reportColors';
import NumberTile from './NumberTile.vue';
import DrillPanel from './DrillPanel.vue';
import ReportNav from './ReportNav.vue';
import DealLines from './DealLines.vue';

const { t, locale } = useI18n();
const store = useStore();
const { money, number, dateTime } = useCrmFormat();
const isAdmin = useMapGetter('crm/status/isAdmin');
const statusFlags = useMapGetter('crm/status/getUIFlags');

const D = (key, args) => t(`CRM.REPORTS.WAVE.DASHBOARD.${key}`, args);

// What each card reads: the report and its period (the month ahead, the month so far, or the last 7 days)
const month = forwardRange('month');
const monthSoFar = periodRange('month');
const lastWeek = periodRange('last_7');
const MINE = {
  pipeline_by_stage: {},
  closing: month,
  stale: {},
  my_tasks: monthSoFar,
  quota: month,
  forecast: month,
};
const TEAM = {
  quota: month,
  forecast: month,
  coverage: month,
  changes: lastWeek,
  conversion: monthSoFar,
  data_quality: {},
  stale: {},
};
const sources = computed(() => (isAdmin.value ? TEAM : MINE));

const reports = ref({});
const isLoading = ref(true);
const isUnavailable = ref(false);
const updatedAt = ref('');

const load = async () => {
  isLoading.value = true;
  isUnavailable.value = false;
  try {
    const entries = await Promise.all(
      Object.entries(sources.value).map(async ([key, params]) => [
        key,
        (await crmReportsAPI.report(key, params)).data,
      ])
    );
    reports.value = Object.fromEntries(entries);
    updatedAt.value = new Intl.DateTimeFormat(locale.value, {
      hour: 'numeric',
      minute: '2-digit',
    }).format(new Date());
  } catch (error) {
    isUnavailable.value = !error?.response || error.response.status >= 500;
  } finally {
    isLoading.value = false;
  }
};

onMounted(async () => {
  // The team or the employee's own board: wait to know which
  if (!statusFlags.value?.hasFetched)
    await store.dispatch('crm/status/fetch').catch(() => {});
  load();
});

const r = key => reports.value[key];
const percent = value =>
  value === null || value === undefined ? '—' : `${number(value)}%`;
const times = value =>
  value === null || value === undefined ? '—' : `${number(value)}×`;
const currency = computed(
  () => Object.values(reports.value)[0]?.currency || 'SAR'
);
const toReport = key => ({ name: 'crm_report', params: { reportKey: key } });

// One drill panel for every card: it lists the deals of whichever report the number came from
const drillPanel = ref(null);
const drillKey = ref('pipeline_by_stage');
const drillParams = computed(() => sources.value[drillKey.value] || {});
const drillColumns = computed(
  () =>
    ({
      stale: ['days_since_activity', 'days_overdue', 'stage'],
      closing: ['close_date', 'stage', 'probability'],
    })[drillKey.value] || ['stage', 'close_date']
);
const drill = async (key, cell, title) => {
  drillKey.value = key;
  await nextTick();
  drillPanel.value?.open(cell, title);
};

// The employee's list of what to move today: late tasks, quiet deals, and deals closing soonest
const LIST = 5;
const lateTasks = computed(() =>
  (r('my_tasks')?.rows || []).filter(task => task.overdue).slice(0, LIST)
);
const quietDeals = computed(() => (r('stale')?.rows || []).slice(0, LIST));
const closingSoon = computed(() => (r('closing')?.rows || []).slice(0, LIST));

// The manager's alerts: each one a sentence and the report that explains it
const alerts = computed(() => {
  if (!isAdmin.value) return [];
  const list = [];
  const conversion = r('conversion');
  const leak = conversion?.rows?.find(
    row => row.stage_id === conversion.leak_stage_id
  );
  if (leak)
    list.push({
      key: 'conversion',
      tone: 'warn',
      text: D('ALERT_LEAK', { stage: leak.name, rate: percent(leak.rate) }),
    });
  const weakest = r('coverage')?.assignees?.find(row => row.rating === 'bad');
  if (weakest)
    list.push({
      key: 'coverage',
      tone: 'bad',
      text: D('ALERT_COVERAGE', {
        name: weakest.name || t('CRM.COMMON.UNASSIGNED'),
        coverage: times(weakest.coverage),
      }),
    });
  const toFix = r('data_quality')?.totals?.to_fix;
  if (toFix)
    list.push({
      key: 'data_quality',
      tone: 'warn',
      text: D('ALERT_DATA', { count: number(toFix) }),
    });
  const atRisk = r('stale')?.totals?.at_risk;
  if (atRisk?.count)
    list.push({
      key: 'stale',
      tone: 'bad',
      text: D('ALERT_STALE', {
        count: number(atRisk.count),
        value: money(atRisk.total_cents, currency.value),
      }),
    });
  return list;
});
const alertClass = tone =>
  tone === 'bad' ? COLORS.lost.text : COLORS.warn.text;

const progress = value => Math.min(100, Number(value) || 0);
const waterfall = computed(() => r('changes')?.totals?.waterfall);
const changeCounts = computed(() => r('changes')?.totals?.counts || {});
</script>

<template>
  <div class="flex flex-col h-full min-w-0 lg:flex-row">
    <ReportNav current="dashboard" />
    <div class="flex flex-col flex-1 min-w-0 overflow-y-auto">
      <CrmPageHeader
        :title="isAdmin ? D('TEAM') : D('MINE')"
        :subtitle="isAdmin ? D('TEAM_HINT') : D('MINE_HINT')"
      />
      <p
        v-if="updatedAt"
        class="px-6 -mt-2 pb-4 text-label-small text-n-slate-10"
      >
        {{ D('UPDATED', { time: updatedAt }) }}
      </p>

      <CrmUnavailable
        v-if="isUnavailable"
        :is-loading="isLoading"
        @retry="load"
      />
      <div
        v-else-if="isLoading && !Object.keys(reports).length"
        class="flex items-center justify-center flex-1 py-16"
      >
        <Spinner />
      </div>

      <!-- «لوحتي» -->
      <div v-else-if="!isAdmin" class="flex flex-col gap-6 px-6 pb-8">
        <div class="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5">
          <NumberTile
            :label="D('OPEN')"
            :value="number(r('pipeline_by_stage')?.totals.count)"
            :note="money(r('pipeline_by_stage')?.totals.total_cents, currency)"
            :cell="{}"
            @drill="(cell, title) => drill('pipeline_by_stage', cell, title)"
          />
          <NumberTile
            :label="D('CLOSING')"
            :value="number(r('closing')?.totals.count)"
            :note="money(r('closing')?.totals.total_cents, currency)"
            :cell="{}"
            @drill="(cell, title) => drill('closing', cell, title)"
          />
          <NumberTile
            :label="D('STALE')"
            :value="number(r('stale')?.totals.at_risk.count)"
            :tone="r('stale')?.totals.at_risk.count ? 'bad' : ''"
            :cell="{}"
            @drill="(cell, title) => drill('stale', cell, title)"
          />
          <NumberTile
            :label="D('TASKS')"
            :value="number(r('my_tasks')?.totals.overdue_count)"
            :note="
              D('TASKS_TODAY', {
                count: number(r('my_tasks')?.totals.today_count),
              })
            "
            :tone="r('my_tasks')?.totals.overdue_count ? 'bad' : ''"
          />
          <NumberTile
            :label="D('FORECAST')"
            :value="money(r('forecast')?.totals.forecast_cents, currency)"
            :note="
              D('OF_TARGET', {
                target: money(r('forecast')?.totals.target_cents, currency),
              })
            "
          />
        </div>

        <router-link
          :to="toReport('quota')"
          class="block p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak hover:bg-n-alpha-1"
        >
          <div class="flex flex-wrap items-baseline justify-between gap-2 mb-3">
            <h2 class="text-heading-3 text-n-slate-12">{{ D('MY_TARGET') }}</h2>
            <span class="text-lg font-semibold tabular-nums text-n-slate-12">
              {{ percent(r('quota')?.totals.attainment) }}
            </span>
          </div>
          <div class="h-3 rounded-full bg-n-slate-3" aria-hidden="true">
            <div
              class="h-full rounded-full"
              :class="
                progress(r('quota')?.totals.attainment) >= 100
                  ? COLORS.won.bar
                  : COLORS.open.bar
              "
              :style="{ width: `${progress(r('quota')?.totals.attainment)}%` }"
            />
          </div>
          <p class="mt-2 text-label-small text-n-slate-11">
            {{
              D('TARGET_LINE', {
                won: money(r('quota')?.totals.won_cents, currency),
                target: money(r('quota')?.totals.target_cents, currency),
                left: money(r('quota')?.totals.remaining_cents, currency),
              })
            }}
          </p>
        </router-link>

        <section>
          <h2 class="mb-3 text-heading-3 text-n-slate-12">{{ D('TODAY') }}</h2>
          <div class="grid grid-cols-1 gap-4 xl:grid-cols-3">
            <div
              class="p-4 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
            >
              <router-link
                :to="toReport('my_tasks')"
                class="block mb-2 text-body-main font-medium text-n-slate-12 hover:text-n-brand"
              >
                {{ D('LATE_TASKS') }}
              </router-link>
              <ul v-if="lateTasks.length" class="divide-y divide-n-weak">
                <li
                  v-for="task in lateTasks"
                  :key="task.id"
                  class="py-2 text-body-main"
                >
                  <router-link
                    :to="{ name: 'crm_task', params: { taskId: task.id } }"
                    class="block truncate text-n-slate-12 hover:text-n-brand"
                  >
                    {{ task.title }}
                  </router-link>
                  <span class="text-label-small" :class="COLORS.lost.text">
                    {{ dateTime(task.due_at) }}
                  </span>
                </li>
              </ul>
              <p v-else class="text-label-small text-n-slate-10">
                {{ D('NOTHING') }}
              </p>
            </div>
            <div
              class="p-4 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
            >
              <router-link
                :to="toReport('stale')"
                class="block mb-2 text-body-main font-medium text-n-slate-12 hover:text-n-brand"
              >
                {{ D('QUIET_DEALS') }}
              </router-link>
              <DealLines
                v-if="quietDeals.length"
                :deals="quietDeals"
                :columns="['days_since_activity']"
                :currency="currency"
              />
              <p v-else class="text-label-small text-n-slate-10">
                {{ D('NOTHING') }}
              </p>
            </div>
            <div
              class="p-4 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
            >
              <router-link
                :to="toReport('closing')"
                class="block mb-2 text-body-main font-medium text-n-slate-12 hover:text-n-brand"
              >
                {{ D('CLOSING_SOON') }}
              </router-link>
              <DealLines
                v-if="closingSoon.length"
                :deals="closingSoon"
                :columns="['close_date']"
                :currency="currency"
              />
              <p v-else class="text-label-small text-n-slate-10">
                {{ D('NOTHING') }}
              </p>
            </div>
          </div>
        </section>
      </div>

      <!-- «لوحة الفريق» -->
      <div v-else class="flex flex-col gap-6 px-6 pb-8">
        <div class="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-5">
          <NumberTile
            :label="D('TEAM_ATTAINMENT')"
            :value="percent(r('quota')?.totals.attainment)"
            :note="
              D('OF_TARGET', {
                target: money(r('quota')?.totals.target_cents, currency),
              })
            "
            :tone="r('quota')?.totals.attainment >= 100 ? 'good' : ''"
          />
          <NumberTile
            :label="D('WON')"
            :value="money(r('quota')?.totals.won_cents, currency)"
            :cell="{}"
            tone="good"
            @drill="(cell, title) => drill('quota', cell, title)"
          />
          <NumberTile
            :label="D('FORECAST')"
            :value="money(r('forecast')?.totals.forecast_cents, currency)"
            :note="
              D('FORECAST_NOTE', {
                rate: percent(r('forecast')?.totals.forecast_attainment),
              })
            "
          />
          <NumberTile
            :label="D('COVERAGE')"
            :value="times(r('coverage')?.totals.coverage)"
            :tone="
              r('coverage')?.totals.rating === 'good'
                ? 'good'
                : r('coverage')?.totals.rating || ''
            "
            :cell="{ status: 'open' }"
            @drill="(cell, title) => drill('coverage', cell, title)"
          />
          <NumberTile
            :label="D('COMPLETE')"
            :value="percent(r('data_quality')?.totals.rate)"
            :note="
              D('TO_FIX', { count: number(r('data_quality')?.totals.to_fix) })
            "
          />
        </div>

        <section v-if="alerts.length" class="flex flex-col gap-2">
          <router-link
            v-for="alert in alerts"
            :key="alert.key"
            :to="toReport(alert.key)"
            class="flex items-center gap-2 px-4 py-3 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak hover:bg-n-alpha-1 text-body-main"
          >
            <span
              class="i-lucide-triangle-alert size-4 shrink-0"
              :class="alertClass(alert.tone)"
              aria-hidden="true"
            />
            <span class="text-n-slate-12">{{ alert.text }}</span>
            <span
              class="i-lucide-chevron-left size-4 ms-auto text-n-slate-10 ltr:rotate-180"
              aria-hidden="true"
            />
          </router-link>
        </section>

        <div class="grid grid-cols-1 gap-6 xl:grid-cols-2">
          <router-link
            :to="toReport('quota')"
            class="block p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak hover:bg-n-alpha-1"
          >
            <h2 class="mb-4 text-heading-3 text-n-slate-12">
              {{ D('RANKING') }}
            </h2>
            <ol
              v-if="r('quota')?.assignees?.length"
              class="flex flex-col gap-3"
            >
              <li
                v-for="row in r('quota').assignees"
                :key="row.assignee_id ?? 'none'"
                class="grid items-center grid-cols-[1.5rem_8rem_1fr_auto] gap-2 text-body-main"
              >
                <span class="tabular-nums text-n-slate-10">{{
                  number(row.rank)
                }}</span>
                <span class="truncate text-n-slate-12">{{
                  row.name || t('CRM.COMMON.UNASSIGNED')
                }}</span>
                <div class="h-2 rounded-full bg-n-slate-3" aria-hidden="true">
                  <div
                    class="h-full rounded-full"
                    :class="
                      progress(row.attainment) >= 100
                        ? COLORS.won.bar
                        : COLORS.open.bar
                    "
                    :style="{ width: `${progress(row.attainment)}%` }"
                  />
                </div>
                <span class="tabular-nums text-n-slate-12">{{
                  percent(row.attainment)
                }}</span>
              </li>
            </ol>
            <p v-else class="text-body-main text-n-slate-11">
              {{ D('NO_TARGETS') }}
            </p>
          </router-link>

          <router-link
            :to="toReport('changes')"
            class="block p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak hover:bg-n-alpha-1"
          >
            <h2 class="mb-4 text-heading-3 text-n-slate-12">{{ D('WEEK') }}</h2>
            <dl class="grid grid-cols-3 gap-3 mb-4">
              <div
                v-for="move in [
                  'new',
                  'won',
                  'lost',
                  'advanced',
                  'moved_back',
                  'slipped',
                ]"
                :key="move"
              >
                <dt class="text-label-small text-n-slate-11">
                  {{ t(`CRM.REPORTS.WAVE.CHANGES.MOVES.${move}`) }}
                </dt>
                <dd class="text-lg font-semibold tabular-nums text-n-slate-12">
                  {{ number(changeCounts[move] || 0) }}
                </dd>
              </div>
            </dl>
            <p v-if="waterfall" class="text-label-small text-n-slate-11">
              {{
                D('WEEK_VALUE', {
                  start: money(waterfall.start, currency),
                  end: money(waterfall.end, currency),
                })
              }}
            </p>
          </router-link>
        </div>
      </div>

      <DrillPanel
        ref="drillPanel"
        :report-key="drillKey"
        :params="drillParams"
        :currency="currency"
        :columns="drillColumns"
        :show-assignee="isAdmin"
      />
    </div>
  </div>
</template>
