// Custom (MyDesk): conversation times in Arabic. Upstream formats them with date-fns in English only
// ("Oct 28, 12:16 AM", "1h • 19m"); other languages keep that behaviour. Day headings (dayLabel) are new
// and use Intl for every language.
import { isArabic, intlLocale } from './reportFormatters';

export { isArabic };

const MINUTE = 60;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const MONTH = 30 * DAY;
const YEAR = 365 * DAY;

// Largest unit first: «الآن», «5 د», «2 س», «3 ي», «1 ش», «2 سنة»
const SHORT_UNITS = [
  { seconds: YEAR, label: 'سنة' },
  { seconds: MONTH, label: 'ش' },
  { seconds: DAY, label: 'ي' },
  { seconds: HOUR, label: 'س' },
  { seconds: MINUTE, label: 'د' },
];

/**
 * Compact time since a Unix timestamp, for conversation cards.
 * @param {number} time - Unix timestamp in seconds.
 * @param {number} [now=Date.now()] - Current time in milliseconds.
 * @returns {string}
 */
export const shortTimeAgo = (time, now = Date.now()) => {
  const elapsed = Math.max(0, Math.floor(now / 1000 - Number(time)));
  const unit = SHORT_UNITS.find(({ seconds }) => elapsed >= seconds);
  if (!unit) return 'الآن';
  return `${Math.floor(elapsed / unit.seconds)} ${unit.label}`;
};

const formatters = new Map();
const formatterFor = (locale, withYear) => {
  const key = `${locale}/${withYear}`;
  if (!formatters.has(key)) {
    formatters.set(
      key,
      new Intl.DateTimeFormat(intlLocale(locale), {
        day: 'numeric',
        month: 'short',
        ...(withYear ? { year: 'numeric' } : {}),
        hour: 'numeric',
        minute: '2-digit',
      })
    );
  }
  return formatters.get(key);
};

const DAY_MS = 86400000;
const startOfDay = date =>
  new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();

const dayFormatters = new Map();
const dayFormatterFor = (locale, style) => {
  const key = `${locale}/${style}`;
  if (!dayFormatters.has(key)) {
    const options = {
      week: { weekday: 'long' },
      date: { weekday: 'long', day: 'numeric', month: 'long' },
      year: { day: 'numeric', month: 'long', year: 'numeric' },
    }[style];
    dayFormatters.set(
      key,
      new Intl.DateTimeFormat(intlLocale(locale), options)
    );
  }
  return dayFormatters.get(key);
};

/**
 * Local calendar day of a Unix timestamp, used to split a conversation into days.
 * @param {number} time - Unix timestamp in seconds.
 * @returns {number}
 */
export const dayKey = time => startOfDay(new Date(Number(time) * 1000));

/**
 * Heading of a day in a conversation: «اليوم», «أمس», the weekday within the past week,
 * then «السبت، 25 أكتوبر», with the year for earlier years. Works for any locale.
 * @param {number} time - Unix timestamp in seconds.
 * @param {string} locale - BCP 47 locale (already normalized).
 * @param {{today: string, yesterday: string}} labels - Translated words for today / yesterday.
 * @param {Date} [now=new Date()]
 * @returns {string}
 */
export const dayLabel = (time, locale, labels, now = new Date()) => {
  const date = new Date(Number(time) * 1000);
  const daysAgo = Math.round((startOfDay(now) - startOfDay(date)) / DAY_MS);
  if (daysAgo === 0) return labels.today;
  if (daysAgo === 1) return labels.yesterday;
  if (daysAgo > 1 && daysAgo < 7) {
    return dayFormatterFor(locale, 'week').format(date);
  }
  const style = date.getFullYear() === now.getFullYear() ? 'date' : 'year';
  return dayFormatterFor(locale, style).format(date);
};

/**
 * Date and time of a message, «28 أكتوبر، 12:16 ص»; the year only when it is not this year.
 * @param {number} time - Unix timestamp in seconds.
 * @param {string} locale
 * @param {Date} [now=new Date()]
 * @returns {string}
 */
export const messageDateTime = (time, locale, now = new Date()) => {
  const date = new Date(Number(time) * 1000);
  return formatterFor(locale, date.getFullYear() !== now.getFullYear()).format(
    date
  );
};
