// Custom (MyDesk): the report period shortcuts, as YYYY-MM-DD. "Today" is the day in the account's time zone (picked in
// the general settings, Riyadh until then), as the server counts it (SalesCrm::Period), whatever the time zone of the
// device. The CRM status (store/modules/crm/status.js) sets it once the server says which one it is.
import { zonedTimeToUtc } from 'date-fns-tz';

export const DEFAULT_TIME_ZONE = 'Asia/Riyadh';
let salesTimeZone = DEFAULT_TIME_ZONE;

export const setSalesTimeZone = timeZone => {
  salesTimeZone = timeZone || DEFAULT_TIME_ZONE;
};

// The calendar day of an instant in that time zone, as a local Date at midnight (so getDate() and friends read its day)
export const salesToday = (instant = new Date()) => {
  const [year, month, day] = new Intl.DateTimeFormat('en-CA', {
    timeZone: salesTimeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  })
    .format(instant)
    .split('-')
    .map(Number);
  return new Date(year, month - 1, day);
};

const iso = d => {
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

// A calendar day (as salesToday() gives it) from 00:00:00 to 23:59:59 in that time zone, in epoch seconds
export const dayBounds = day => {
  const date = iso(day);
  const seconds = time =>
    zonedTimeToUtc(`${date}T${time}`, salesTimeZone).getTime() / 1000;
  return { since: seconds('00:00:00'), until: seconds('23:59:59') };
};

export const periodRange = (period, now = salesToday()) => {
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
    case 'last_7':
      start.setDate(start.getDate() - 6);
      return { from: iso(start), to };
    case 'last_30':
      start.setDate(start.getDate() - 29);
      return { from: iso(start), to };
    case 'last_month':
      return {
        from: iso(new Date(now.getFullYear(), now.getMonth() - 1, 1)),
        to: iso(new Date(now.getFullYear(), now.getMonth(), 0)),
      };
    case 'quarter':
      start.setMonth(Math.floor(start.getMonth() / 3) * 3, 1);
      return { from: iso(start), to };
    case 'year':
      start.setMonth(0, 1);
      return { from: iso(start), to };
    case 'month':
    default:
      start.setDate(1);
      return { from: iso(start), to };
  }
};
