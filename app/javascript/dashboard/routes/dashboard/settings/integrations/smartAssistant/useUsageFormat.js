// Custom (MyDesk): number and money formatting for the smart assistant's token usage
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

// The Saudi riyal is pegged to the US dollar at 3.75; OpenAI bills in dollars
export const SAR_PER_USD = 3.75;
export const USAGE_KINDS = ['reply', 'test', 'knowledge'];
const MIN_REGULAR_AMOUNT = 0.01;
const TOTAL_FIELDS = [
  'input_tokens',
  'output_tokens',
  'cached_tokens',
  'cost',
  'calls',
];

// Sums the per-kind totals the API returns ({ reply: { input_tokens, ... }, ... })
export const sumTotals = byKind =>
  Object.fromEntries(
    TOTAL_FIELDS.map(field => [
      field,
      Object.values(byKind || {})
        .filter(Boolean)
        .reduce((sum, totals) => sum + Number(totals[field] || 0), 0),
    ])
  );

export const useUsageFormat = () => {
  const { locale } = useI18n();

  const numberFormat = computed(() => new Intl.NumberFormat(locale.value));
  // Amounts of a cent or more read as money; a reply costs a fraction of a cent, so smaller amounts keep
  // two significant digits ($0.000058) instead of rounding to $0.00
  const moneyFormats = computed(() =>
    Object.fromEntries(
      ['USD', 'SAR'].map(currency => [
        currency,
        {
          regular: new Intl.NumberFormat(locale.value, {
            style: 'currency',
            currency,
            minimumFractionDigits: 2,
            maximumFractionDigits: 2,
          }),
          small: new Intl.NumberFormat(locale.value, {
            style: 'currency',
            currency,
            maximumSignificantDigits: 2,
          }),
        },
      ])
    )
  );
  const formatMoney = (amount, currency) => {
    const formats = moneyFormats.value[currency];
    return (
      amount > 0 && amount < MIN_REGULAR_AMOUNT
        ? formats.small
        : formats.regular
    ).format(amount);
  };

  return {
    formatNumber: value => numberFormat.value.format(Number(value || 0)),
    formatUsd: value => formatMoney(Number(value || 0), 'USD'),
    formatSar: value => formatMoney(Number(value || 0) * SAR_PER_USD, 'SAR'),
  };
};
