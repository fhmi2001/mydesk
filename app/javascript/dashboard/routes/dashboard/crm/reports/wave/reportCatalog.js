// Custom (MyDesk): the reports of phase 4 (docs/reports/CRM_REPORTS_PLAN.md), in the order of the reports matrix, with
// the filters each one takes. period: 'past' (so far: today … quarter), 'forward' (what is still to close: the whole
// month or quarter), or null for a picture of now. The server applies the same filters (SalesCrm::Reports::Report).
export const REPORTS = [
  {
    key: 'pipeline_by_stage',
    number: 1,
    icon: 'i-lucide-columns-3',
    period: null,
    lists: true,
    columns: ['stage', 'probability', 'close_date'],
  },
  {
    key: 'closing',
    number: 2,
    icon: 'i-lucide-calendar-clock',
    period: 'forward',
    lists: true,
    stage: true,
    columns: ['close_date', 'stage', 'probability'],
  },
  {
    key: 'stale',
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
    number: 4,
    icon: 'i-lucide-list-checks',
    period: 'past',
    tasks: true,
  },
  {
    key: 'won_lost',
    number: 5,
    icon: 'i-lucide-scale',
    period: 'past',
    lists: true,
    columns: ['status', 'closed_at', 'lost_reason'],
  },
  {
    key: 'quota',
    number: 6,
    icon: 'i-lucide-target',
    period: 'forward',
    // Targets are per employee and month, not per pipeline
    noPipeline: true,
    columns: ['closed_at'],
  },
  {
    key: 'forecast',
    number: 7,
    icon: 'i-lucide-trending-up',
    period: 'forward',
    lists: true,
    columns: ['category', 'close_date', 'probability'],
  },
];

export const reportFor = key => REPORTS.find(r => r.key === key) || REPORTS[0];

const iso = d => {
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

// The whole month, quarter or year, for reports about what is still to close; next_month for planning ahead
export const forwardRange = (period, now = new Date()) => {
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
