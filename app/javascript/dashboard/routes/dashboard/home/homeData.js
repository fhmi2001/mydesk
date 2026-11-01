// Custom (MyDesk): the home screen's sources. Each is fetched on its own, so one that fails (null) hides only what
// reads it. The sales sources are not asked for at all when the account's Sales CRM is off.
import ConversationAPI from 'dashboard/api/inbox/conversation';
import ReportsAPI from 'dashboard/api/reports';
import CSATReportsAPI from 'dashboard/api/csatReports';
import SummaryReportsAPI from 'dashboard/api/summaryReports';
import LiveReportsAPI from 'dashboard/api/liveReports';
import { crmReportsAPI, crmTasksAPI } from 'dashboard/api/crm';
import { periodRange, riyadhToday } from '../crm/reports/periods';
import { forwardRange } from '../crm/reports/wave/reportCatalog';

const pad = n => String(n).padStart(2, '0');
const iso = day =>
  `${day.getFullYear()}-${pad(day.getMonth() + 1)}-${pad(day.getDate())}`;

// Deals closing from today through the next 7 days, across a month's end
const CLOSING_DAYS = 7;
const closingSoon = () => {
  const today = riyadhToday();
  const last = new Date(today);
  last.setDate(today.getDate() + CLOSING_DAYS);
  return { from: iso(today), to: iso(last) };
};

// A calendar day (as riyadhToday() gives it) from 00:00:00 to 23:59:59 in Riyadh (UTC+3, no daylight saving)
export const riyadhDayBounds = day => {
  const date = iso(day);
  return {
    since: Date.parse(`${date}T00:00:00+03:00`) / 1000,
    until: Date.parse(`${date}T23:59:59+03:00`) / 1000,
  };
};

const waitingConversations = assigneeType =>
  ConversationAPI.get({
    status: 'open',
    assigneeType,
    sortBy: 'waiting_since_asc',
    page: 1,
  });

// { key: request } → { key: data or null }
const settle = async requests => {
  const keys = Object.keys(requests);
  const results = await Promise.allSettled(Object.values(requests));
  return Object.fromEntries(
    keys.map((key, i) => [
      key,
      results[i].status === 'fulfilled'
        ? (results[i].value?.data ?? null)
        : null,
    ])
  );
};

const withSales = (crmEnabled, requests) =>
  Object.fromEntries(
    Object.entries(requests).map(([key, request]) => [
      key,
      crmEnabled ? request() : Promise.reject(new Error('Sales CRM is off')),
    ])
  );

// The support reports are the manager's only (ReportPolicy): an employee's home asks for none of them. The pipeline
// report is the employee's own deals, the team's for a manager.
export const loadAgentHome = ({ crmEnabled }) =>
  settle({
    meta: ConversationAPI.meta({ status: 'open' }),
    conversations: waitingConversations('me'),
    ...withSales(crmEnabled, {
      tasks: () => crmReportsAPI.report('my_tasks', periodRange('month')),
      deals: () => crmReportsAPI.report('closing', closingSoon()),
      quota: () => crmReportsAPI.report('quota', forwardRange('month')),
      pipeline: () => crmReportsAPI.report('pipeline_by_stage', {}),
    }),
  });

// The last 7 days, today included
const weekBounds = today => {
  const first = new Date(today);
  first.setDate(today.getDate() - 6);
  return {
    since: riyadhDayBounds(first).since,
    until: riyadhDayBounds(today).until,
  };
};

const daily = (metric, week) =>
  ReportsAPI.getReports({
    metric,
    from: week.since,
    to: week.until,
    groupBy: 'day',
  });

export const loadManagerHome = ({ crmEnabled }) => {
  const today = riyadhToday();
  const todayBounds = riyadhDayBounds(today);
  const week = weekBounds(today);
  return settle({
    meta: ConversationAPI.meta({ status: 'open' }),
    waiting: waitingConversations('all'),
    // Carries yesterday's figures too, as `previous`
    summary: ReportsAPI.getSummary(todayBounds.since, todayBounds.until),
    traffic: daily('conversations_count', week),
    responseTrend: daily('avg_first_response_time', week),
    channels: SummaryReportsAPI.getInboxReports(week),
    load: LiveReportsAPI.getGroupedConversations({ groupBy: 'assignee_id' }),
    csat: CSATReportsAPI.getMetrics({
      from: todayBounds.since,
      to: todayBounds.until,
    }),
    ...withSales(crmEnabled, {
      quota: () => crmReportsAPI.report('quota', forwardRange('month')),
      forecast: () => crmReportsAPI.report('forecast', forwardRange('month')),
      conversion: () =>
        crmReportsAPI.report('conversion', periodRange('last_30')),
      stale: () => crmReportsAPI.report('stale', {}),
      lateTasks: () => crmTasksAPI.get({ scope: 'overdue' }),
      pipeline: () => crmReportsAPI.report('pipeline_by_stage', {}),
    }),
  });
};
