// Custom (MyDesk): durations and dates for reports in the user's language. Upstream formatTime always
// writes English units ("1 Min 33 Sec"), which Arabic text then reorders; Arabic gets «1 د 33 ث» instead.
import { formatTime } from '@chatwoot/utils';

export const NO_VALUE = '—';

// Largest unit first; Arabic shows the two largest non-zero units
const ARABIC_UNITS = [
  { seconds: 86400, label: 'ي' },
  { seconds: 3600, label: 'س' },
  { seconds: 60, label: 'د' },
  { seconds: 1, label: 'ث' },
];

export const isArabic = locale => String(locale || '').startsWith('ar');

// Western digits and the Gregorian calendar, the convention of Saudi commerce screens
export const intlLocale = locale =>
  isArabic(locale) ? 'ar-u-nu-latn-ca-gregory' : locale || 'en';

export const formatNumber = (value, locale) =>
  new Intl.NumberFormat(intlLocale(locale)).format(Number(value) || 0);

export const formatDuration = (seconds, locale) => {
  const total = Math.max(0, Math.round(Number(seconds) || 0));
  if (!isArabic(locale)) return formatTime(total);
  if (total === 0) return `0 ${ARABIC_UNITS[3].label}`;

  let remaining = total;
  const parts = [];
  ARABIC_UNITS.forEach(({ seconds: size, label }) => {
    const amount = Math.floor(remaining / size);
    remaining -= amount * size;
    if (amount && parts.length < 2) parts.push(`${amount} ${label}`);
  });
  return parts.join(' ');
};

const DATE_STYLES = {
  day: { day: 'numeric', month: 'short' },
  month: { month: 'short', year: 'numeric' },
  year: { year: 'numeric' },
  date: { day: 'numeric', month: 'short', year: 'numeric' },
  dateTime: {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  },
};

export const formatReportDate = (date, style, locale) =>
  new Intl.DateTimeFormat(intlLocale(locale), DATE_STYLES[style]).format(
    date instanceof Date ? date : new Date(date)
  );
