// Custom (MyDesk): the report period shortcuts, as YYYY-MM-DD in the browser's local calendar
const iso = d => {
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

export const periodRange = (period, now = new Date()) => {
  const to = iso(now);
  const start = new Date(now);
  switch (period) {
    case 'today':
      return { from: to, to };
    case 'week': {
      // Saturday starts the week in Saudi Arabia
      const day = (start.getDay() + 1) % 7; // Sat=0 … Fri=6
      start.setDate(start.getDate() - day);
      return { from: iso(start), to };
    }
    case 'quarter':
      start.setMonth(Math.floor(start.getMonth() / 3) * 3, 1);
      return { from: iso(start), to };
    case 'month':
    default:
      start.setDate(1);
      return { from: iso(start), to };
  }
};
