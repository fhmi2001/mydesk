// Custom (MyDesk): money, digits and plurals for the Sales CRM, in Arabic and English

const ARABIC_INDIC = '٠١٢٣٤٥٦٧٨٩';
const EXTENDED_ARABIC_INDIC = '۰۱۲۳۴۵۶۷۸۹';

// Arabic-Indic digits (both sets) to Western digits; other characters untouched
export const toWesternDigits = value =>
  String(value ?? '').replace(/[٠-٩۰-۹]/g, d => {
    const i = ARABIC_INDIC.indexOf(d);
    return String(i >= 0 ? i : EXTENDED_ARABIC_INDIC.indexOf(d));
  });

// "50,000.50", "٥٠٬٠٠٠٫٥", "50000" → cents (integer); null when not a number
export const parseAmount = input => {
  if (input === null || input === undefined) return null;
  const text = toWesternDigits(input)
    .replace(/[,٬\s]/g, '')
    .replace(/٫/g, '.')
    .trim();
  if (text === '' || !/^\d+(\.\d{0,2})?$/.test(text)) return null;
  const [whole, fraction = ''] = text.split('.');
  return Number(whole) * 100 + Number((fraction + '00').slice(0, 2));
};

const localeTag = locale =>
  String(locale).startsWith('ar') ? 'ar-SA' : 'en-US';

// 5000000, 'SAR', 'ar' → "50,000.00 ر.س." ; 'en' → "SAR 50,000.00". Western digits in both languages.
export const formatMoney = (cents, currency = 'SAR', locale = 'en') => {
  const amount = (Number(cents) || 0) / 100;
  try {
    return new Intl.NumberFormat(localeTag(locale), {
      style: 'currency',
      currency,
      numberingSystem: 'latn',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(amount);
  } catch (e) {
    return `${amount.toFixed(2)} ${currency}`;
  }
};

export const formatCompactMoney = (cents, currency = 'SAR', locale = 'en') => {
  const amount = (Number(cents) || 0) / 100;
  try {
    return new Intl.NumberFormat(localeTag(locale), {
      style: 'currency',
      currency,
      numberingSystem: 'latn',
      notation: 'compact',
      maximumFractionDigits: 1,
    }).format(amount);
  } catch (e) {
    return formatMoney(cents, currency, locale);
  }
};

export const formatNumber = (value, locale = 'en') =>
  new Intl.NumberFormat(localeTag(locale), { numberingSystem: 'latn' }).format(
    Number(value) || 0
  );

// Arabic has six plural categories; the translation holds one string per category under `key`.
// Every string may use {count}.
const arabicCategory = n => {
  if (n === 0) return 'zero';
  if (n === 1) return 'one';
  if (n === 2) return 'two';
  const mod = n % 100;
  if (mod >= 3 && mod <= 10) return 'few';
  if (mod >= 11 && mod <= 99) return 'many';
  return 'other';
};

export const pluralCategory = (count, locale = 'en') => {
  const n = Math.abs(Math.trunc(Number(count) || 0));
  if (String(locale).startsWith('ar')) return arabicCategory(n);
  return n === 1 ? 'one' : 'other';
};

// t: vue-i18n's translate. key points at an object of plural forms in crm.json.
export const crmPlural = (t, key, count, locale = 'en') =>
  t(`${key}.${pluralCategory(count, locale)}`, {
    count: formatNumber(count, locale),
  });

// A date/time for display in the account's time zone
export const formatDateTime = (
  iso,
  locale = 'en',
  timeZone = 'Asia/Riyadh'
) => {
  if (!iso) return '';
  try {
    return new Intl.DateTimeFormat(localeTag(locale), {
      numberingSystem: 'latn',
      timeZone,
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }).format(new Date(iso));
  } catch (e) {
    return String(iso);
  }
};

export const formatDate = (iso, locale = 'en', timeZone = 'Asia/Riyadh') => {
  if (!iso) return '';
  try {
    return new Intl.DateTimeFormat(localeTag(locale), {
      numberingSystem: 'latn',
      timeZone,
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    }).format(new Date(iso));
  } catch (e) {
    return String(iso);
  }
};

// ISO instant → value for <input type="datetime-local"> in the given zone (YYYY-MM-DDTHH:MM)
export const toLocalInputValue = (iso, timeZone = 'Asia/Riyadh') => {
  if (!iso) return '';
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(new Date(iso));
  const get = type => parts.find(p => p.type === type)?.value;
  return `${get('year')}-${get('month')}-${get('day')}T${get('hour') === '24' ? '00' : get('hour')}:${get('minute')}`;
};

const zoneOffsetMinutes = (date, timeZone) => {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hour12: false,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).formatToParts(date);
  const get = type => Number(parts.find(p => p.type === type)?.value);
  const asUtc = Date.UTC(
    get('year'),
    get('month') - 1,
    get('day'),
    get('hour') % 24,
    get('minute')
  );
  return Math.round((asUtc - date.getTime()) / 60000);
};

// <input type="datetime-local"> value in the given zone → ISO instant
export const fromLocalInputValue = (value, timeZone = 'Asia/Riyadh') => {
  if (!value) return null;
  const [date, time = '00:00'] = value.split('T');
  const [y, m, d] = date.split('-').map(Number);
  const [hh, mm] = time.split(':').map(Number);
  const guess = Date.UTC(y, m - 1, d, hh, mm);
  const offset = zoneOffsetMinutes(new Date(guess), timeZone);
  return new Date(guess - offset * 60000).toISOString();
};
