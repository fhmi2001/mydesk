// Custom (MyDesk): the Sales reports (docs/reports/CRM_REPORTS_PLAN.md), in the order of the reports matrix, with
// the filters each one takes. period: 'past' (so far: today … quarter), 'forward' (what is still to close: the whole
// month or quarter), or null for a picture of now. The server applies the same filters (SalesCrm::Reports::Report).
import { salesToday } from '../periods';

export const REPORTS = [
  {
    key: 'pipeline_by_stage',
    group: 'pipeline',
    number: 1,
    icon: 'i-lucide-columns-3',
    period: null,
    lists: true,
    columns: ['stage', 'probability', 'close_date'],
  },
  {
    key: 'closing',
    group: 'pipeline',
    number: 2,
    icon: 'i-lucide-calendar-clock',
    period: 'forward',
    lists: true,
    stage: true,
    columns: ['close_date', 'stage', 'probability'],
  },
  {
    key: 'stale',
    group: 'health',
    number: 3,
    icon: 'i-lucide-hourglass',
    period: null,
    lists: true,
    stage: true,
    days: true,
    columns: ['days_since_activity', 'days_overdue', 'stage'],
  },
  {
    key: 'my_tasks',
    group: 'activity',
    number: 4,
    icon: 'i-lucide-list-checks',
    period: 'past',
    tasks: true,
  },
  {
    key: 'won_lost',
    group: 'results',
    number: 5,
    icon: 'i-lucide-scale',
    period: 'past',
    lists: true,
    columns: ['status', 'closed_at', 'lost_reason'],
  },
  {
    key: 'quota',
    group: 'performance',
    number: 6,
    icon: 'i-lucide-target',
    period: 'forward',
    // Targets are per employee and month, not per pipeline
    noPipeline: true,
    columns: ['closed_at'],
  },
  {
    key: 'forecast',
    group: 'forecast',
    number: 7,
    icon: 'i-lucide-trending-up',
    period: 'forward',
    lists: true,
    columns: ['category', 'close_date', 'probability'],
  },
  // Wave ب
  {
    key: 'coverage',
    group: 'forecast',
    number: 8,
    icon: 'i-lucide-shield-check',
    period: 'forward',
    noPipeline: true,
    columns: ['close_date', 'stage', 'probability'],
  },
  {
    key: 'win_rate',
    group: 'conversion',
    number: 10,
    icon: 'i-lucide-percent',
    period: 'past',
    lists: true,
    groups: true,
    columns: ['status', 'closed_at', 'lost_reason'],
  },
  {
    key: 'losses',
    group: 'results',
    number: 12,
    icon: 'i-lucide-circle-x',
    period: 'past',
    lists: true,
    columns: ['closed_at', 'lost_reason'],
  },
  {
    key: 'activity',
    group: 'activity',
    number: 14,
    icon: 'i-lucide-activity',
    period: 'past',
    // The team's activity is for the manager (the server refuses anyone else)
    adminOnly: true,
    columns: ['closed_at'],
  },
  {
    key: 'new_deals',
    group: 'pipeline',
    number: 15,
    icon: 'i-lucide-sprout',
    period: 'past',
    lists: true,
    columns: ['stage', 'close_date'],
  },
  {
    key: 'data_quality',
    group: 'health',
    number: 16,
    icon: 'i-lucide-list-checks',
    period: null,
    lists: true,
    stage: true,
    columns: ['issues', 'stage', 'close_date'],
  },
  {
    key: 'scorecard',
    group: 'performance',
    number: 19,
    icon: 'i-lucide-id-card',
    period: 'forward',
    noPipeline: true,
    columns: ['stage', 'close_date'],
  },
  // Wave ج
  {
    key: 'conversion',
    group: 'conversion',
    number: 9,
    icon: 'i-lucide-filter',
    period: 'past',
    lists: true,
    columns: ['stage', 'close_date'],
  },
  {
    key: 'cycle',
    group: 'conversion',
    number: 11,
    icon: 'i-lucide-timer',
    period: 'past',
    lists: true,
    adminOnly: true,
    columns: ['stage', 'closed_at'],
  },
  {
    key: 'changes',
    group: 'pipeline',
    number: 13,
    icon: 'i-lucide-git-compare-arrows',
    period: 'past',
    periods: ['last_7', 'week', 'month', 'last_month', 'custom'],
    defaultPeriod: 'last_7',
    lists: true,
    adminOnly: true,
    columns: ['stage', 'close_date'],
  },
  {
    key: 'revenue',
    group: 'results',
    number: 17,
    icon: 'i-lucide-coins',
    period: 'past',
    groups: true,
    adminOnly: true,
    columns: ['closed_at'],
  },
  {
    key: 'deal_size',
    group: 'results',
    number: 18,
    icon: 'i-lucide-ruler',
    period: 'past',
    defaultPeriod: 'year',
    lists: true,
    adminOnly: true,
    columns: ['closed_at'],
  },
  // Conversations and sales (docs/mydesk/CONVERSATION_SALES_PLAN.md)
  {
    key: 'response_speed',
    group: 'conversion',
    number: 20,
    icon: 'i-lucide-timer',
    period: 'past',
    lists: true,
    columns: ['closed_at', 'stage'],
  },
  {
    key: 'campaigns',
    group: 'results',
    number: 21,
    icon: 'i-lucide-megaphone',
    period: 'past',
    adminOnly: true,
    columns: ['stage', 'close_date'],
  },
  {
    key: 'conversation_deals',
    group: 'conversion',
    number: 22,
    icon: 'i-lucide-messages-square',
    period: 'past',
    columns: ['stage', 'close_date'],
  },
];

// The navigation's groups, in order (CRM_REPORTS_PLAN.md)
export const GROUPS = [
  'pipeline',
  'forecast',
  'results',
  'conversion',
  'performance',
  'activity',
  'health',
];

// The reports a user may open: the manager's own ones are left out for employees
export const reportsFor = isAdmin =>
  REPORTS.filter(r => isAdmin || !r.adminOnly);

export const reportFor = key => REPORTS.find(r => r.key === key) || REPORTS[0];

const iso = d => {
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

// The whole month, quarter or year, for reports about what is still to close; next_month for planning ahead
export const forwardRange = (period, now = salesToday()) => {
  const year = now.getFullYear();
  const month = now.getMonth();
  switch (period) {
    case 'quarter': {
      const first = Math.floor(month / 3) * 3;
      return {
        from: iso(new Date(year, first, 1)),
        to: iso(new Date(year, first + 3, 0)),
      };
    }
    case 'year':
      return {
        from: iso(new Date(year, 0, 1)),
        to: iso(new Date(year, 11, 31)),
      };
    case 'next_month':
      return {
        from: iso(new Date(year, month + 1, 1)),
        to: iso(new Date(year, month + 2, 0)),
      };
    case 'month':
    default:
      return {
        from: iso(new Date(year, month, 1)),
        to: iso(new Date(year, month + 1, 0)),
      };
  }
};

export const PAST_PERIODS = [
  'today',
  'week',
  'month',
  'last_month',
  'quarter',
  'year',
  'custom',
];
export const FORWARD_PERIODS = [
  'month',
  'next_month',
  'quarter',
  'year',
  'custom',
];
