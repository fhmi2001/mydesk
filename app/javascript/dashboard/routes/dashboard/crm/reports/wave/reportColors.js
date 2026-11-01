// Custom (MyDesk): the one meaning each colour has across the Sales reports (CRM_REPORTS_PLAN.md, phase 5): won is
// teal, lost is ruby, open is iris, a warning is amber, a total or "other" is slate. Charts take the rgb() values, the
// rest the classes; the class names are written out whole so Tailwind keeps them.
export const COLORS = {
  won: {
    bar: 'bg-n-teal-9',
    text: 'text-n-teal-11',
    rgb: 'rgb(var(--teal-9))',
    rgbText: 'rgb(var(--teal-11))',
  },
  lost: {
    bar: 'bg-n-ruby-9',
    text: 'text-n-ruby-11',
    rgb: 'rgb(var(--ruby-9))',
    rgbText: 'rgb(var(--ruby-11))',
  },
  open: {
    bar: 'bg-n-iris-9',
    text: 'text-n-iris-11',
    rgb: 'rgb(var(--iris-9))',
    rgbText: 'rgb(var(--iris-11))',
  },
  warn: {
    bar: 'bg-n-amber-9',
    text: 'text-n-amber-11',
    rgb: 'rgb(var(--amber-9))',
    rgbText: 'rgb(var(--amber-11))',
  },
  neutral: {
    bar: 'bg-n-slate-9',
    text: 'text-n-slate-11',
    rgb: 'rgb(var(--slate-8))',
    rgbText: 'rgb(var(--slate-11))',
  },
};

// The text colour of a tone (NumberTile, AssigneeTable): good is won's, bad is lost's, warn is the warning's
export const TONE_TEXT = {
  good: COLORS.won.text,
  bad: `${COLORS.lost.text} font-medium`,
  warn: COLORS.warn.text,
};
