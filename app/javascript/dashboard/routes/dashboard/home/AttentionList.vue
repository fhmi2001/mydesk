<script setup>
// Custom (MyDesk): the home screen's main list: the employee's single items or the manager's counted lines (attention.js).
// Every row is a link to the conversation, task, deal or report behind it.
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useCrmFormat } from '../crm/shared/useCrmFormat';
import { periodRange } from '../crm/reports/periods';

const props = defineProps({
  items: { type: Array, required: true },
  title: { type: String, required: true },
  currency: { type: String, default: 'SAR' },
  // A source of the list failed: say so rather than "nothing waiting"
  failed: { type: Boolean, default: false },
});

const { t } = useI18n();
const { accountScopedRoute } = useAccount();
const { number, money, date, dateTime, plural } = useCrmFormat();

const ICONS = {
  conversation: 'i-lucide-message-circle',
  task_overdue: 'i-lucide-circle-alert',
  task_today: 'i-lucide-circle-check',
  deal: 'i-lucide-handshake',
  unassigned: 'i-lucide-user-round-x',
  waiting_long: 'i-lucide-timer',
  leak: 'i-lucide-filter',
  stale: 'i-lucide-hourglass',
  late_tasks: 'i-lucide-list-checks',
};

const waited = minutes =>
  minutes < 60
    ? t('HOME.WAITED_MINUTES', { count: number(minutes) })
    : t('HOME.WAITED_HOURS', { count: number(Math.floor(minutes / 60)) });

const daysLate = dueAt =>
  Math.max(1, Math.floor((Date.now() - new Date(dueAt)) / 86400000));

const report = (reportKey, query) =>
  accountScopedRoute('crm_report', { reportKey }, query);

const ROWS = {
  // A late one says so in words and with a warning icon, not by its colour alone
  conversation: i => ({
    text: i.title,
    meta: i.urgent
      ? t('HOME.WAITED_LATE', { time: waited(i.detail.minutes) })
      : waited(i.detail.minutes),
    icon: i.urgent ? 'i-lucide-message-circle-warning' : undefined,
    to: accountScopedRoute('inbox_conversation', { conversation_id: i.id }),
  }),
  task_overdue: i => ({
    text: i.title,
    meta: plural('HOME.LATE_DAYS', daysLate(i.detail.dueAt)),
    to: accountScopedRoute('crm_tasks'),
  }),
  task_today: i => ({
    text: i.title,
    meta: t('HOME.DUE_AT', { time: dateTime(i.detail.dueAt) }),
    to: accountScopedRoute('crm_tasks'),
  }),
  deal: i => ({
    text: i.title,
    meta: t('HOME.CLOSES_ON', { date: date(i.detail.closeDate) }),
    to: accountScopedRoute('crm_deal', { dealId: i.id }),
  }),
  unassigned: l => ({
    text: plural('HOME.LINES.UNASSIGNED', l.count),
    to: accountScopedRoute('home', {}, { assignee: 'unassigned' }),
  }),
  waiting_long: l => ({
    text: plural('HOME.LINES.WAITING_LONG', l.count),
    to: accountScopedRoute('home', {}, { assignee: 'all' }),
  }),
  leak: l => ({
    text: t('HOME.LINES.LEAK', {
      stage: l.data.name,
      rate: `${number(l.data.rate)}%`,
    }),
    meta: t('HOME.LINES.LAST_30'),
    // The report on the same last 30 days the line counts
    to: report('conversion', { period: 'custom', ...periodRange('last_30') }),
  }),
  stale: l => ({
    text: plural('HOME.LINES.STALE', l.count),
    meta: money(l.data.amount, props.currency),
    to: report('stale'),
  }),
  late_tasks: l => ({
    text: plural('HOME.LINES.LATE_TASKS', l.count),
    meta: l.data.topName
      ? t('HOME.LINES.MOST', {
          name: l.data.topName,
          count: number(l.data.topCount),
        })
      : '',
    to: accountScopedRoute('crm_tasks'),
  }),
};

const rowFor = entry => {
  const row = ROWS[entry.kind](entry);
  return {
    key: `${entry.kind}-${entry.id ?? ''}`,
    urgent: entry.urgent,
    ...row,
    icon: row.icon || ICONS[entry.kind],
  };
};
</script>

<template>
  <section
    class="flex flex-col p-5 rounded-xl bg-n-solid-1 outline outline-1 -outline-offset-1 outline-n-weak"
  >
    <h2 class="mb-2 text-heading-3 text-n-slate-12">{{ title }}</h2>
    <ul v-if="items.length" class="flex flex-col m-0 list-none">
      <li
        v-for="row in items.map(rowFor)"
        :key="row.key"
        class="border-t border-n-weak first:border-t-0"
      >
        <router-link
          :to="row.to"
          class="flex items-center gap-3 py-3 -mx-2 px-2 rounded-lg hover:bg-n-alpha-1 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
        >
          <span
            :class="[
              row.icon,
              row.urgent ? 'text-n-ruby-11' : 'text-n-slate-11',
            ]"
            class="size-4 shrink-0"
            aria-hidden="true"
          />
          <span class="flex-1 min-w-0 truncate text-body-main text-n-slate-12">
            {{ row.text }}
          </span>
          <span
            v-if="row.meta"
            class="shrink-0 text-label-small tabular-nums"
            :class="row.urgent ? 'text-n-ruby-11' : 'text-n-slate-11'"
          >
            {{ row.meta }}
          </span>
        </router-link>
      </li>
    </ul>
    <p
      v-if="failed"
      class="flex items-center gap-2 py-3 text-label-small text-n-slate-11"
      :class="{ 'border-t border-n-weak': items.length }"
    >
      <span class="i-lucide-circle-alert size-4 shrink-0" aria-hidden="true" />
      {{ t('HOME.LIST_FAILED') }}
    </p>
    <div v-else-if="!items.length" class="flex flex-col items-start gap-2 py-6">
      <p class="text-body-main text-n-slate-11">{{ t('HOME.EMPTY') }}</p>
      <router-link
        :to="accountScopedRoute('home')"
        class="text-label-small text-n-slate-12 underline underline-offset-2"
      >
        {{ t('HOME.OPEN_CONVERSATIONS') }}
      </router-link>
    </div>
  </section>
</template>
