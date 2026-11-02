// Custom (MyDesk): formatters bound to the user's language and the account's time zone
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import {
  formatMoney,
  formatCompactMoney,
  formatNumber,
  formatDate,
  formatDateTime,
  crmPlural,
} from 'dashboard/helper/crmFormat';

export function useCrmFormat() {
  const { t, locale } = useI18n();
  const timezone = useMapGetter('crm/status/timezone');
  const lang = computed(() => String(locale.value || 'en'));

  return {
    money: (cents, currency = 'SAR') =>
      formatMoney(cents, currency, lang.value),
    compactMoney: (cents, currency = 'SAR') =>
      formatCompactMoney(cents, currency, lang.value),
    number: value => formatNumber(value, lang.value),
    date: iso => formatDate(iso, lang.value, timezone.value),
    dateTime: iso => formatDateTime(iso, lang.value, timezone.value),
    plural: (key, count) => crmPlural(t, key, count, lang.value),
    timezone,
    lang,
  };
}
