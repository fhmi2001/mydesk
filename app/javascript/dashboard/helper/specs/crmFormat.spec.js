// Custom (MyDesk)
import {
  parseAmount,
  formatMoney,
  pluralCategory,
  crmPlural,
  toLocalInputValue,
  fromLocalInputValue,
} from '../crmFormat';

describe('crmFormat', () => {
  it('parses Western, grouped and Arabic-Indic amounts to cents', () => {
    expect(parseAmount('50000')).toBe(5000000);
    expect(parseAmount('50,000.50')).toBe(5000050);
    expect(parseAmount('٥٠٬٠٠٠')).toBe(5000000);
    expect(parseAmount('٥٠٬٠٠٠٫٥')).toBe(5000050);
    expect(parseAmount('1.5')).toBe(150);
    expect(parseAmount('')).toBeNull();
    expect(parseAmount('abc')).toBeNull();
    expect(parseAmount('-5')).toBeNull();
  });

  it('formats money per locale with Western digits', () => {
    expect(formatMoney(5000000, 'SAR', 'ar')).toContain('50,000.00');
    expect(formatMoney(5000000, 'SAR', 'en').replace(/\u00a0/g, ' ')).toBe(
      'SAR 50,000.00'
    );
    expect(formatMoney(5000000, 'SAR', 'ar')).not.toMatch(/[٠-٩]/);
  });

  it('picks the Arabic plural category', () => {
    expect(
      [0, 1, 2, 3, 10, 11, 99, 100, 102].map(n => pluralCategory(n, 'ar'))
    ).toEqual([
      'zero',
      'one',
      'two',
      'few',
      'few',
      'many',
      'many',
      'other',
      'other',
    ]);
    expect(pluralCategory(1, 'en')).toBe('one');
    expect(pluralCategory(5, 'en')).toBe('other');
  });

  it('crmPlural resolves the form and injects the count', () => {
    const t = (key, params) => `${key}:${params.count}`;
    expect(crmPlural(t, 'CRM.DEALS_COUNT', 3, 'ar')).toBe(
      'CRM.DEALS_COUNT.few:3'
    );
    expect(crmPlural(t, 'CRM.DEALS_COUNT', 1, 'en')).toBe(
      'CRM.DEALS_COUNT.one:1'
    );
  });

  it('round-trips datetime-local values through the Riyadh time zone', () => {
    const iso = fromLocalInputValue('2026-10-31T23:30', 'Asia/Riyadh');
    expect(iso).toBe('2026-10-31T20:30:00.000Z');
    expect(toLocalInputValue(iso, 'Asia/Riyadh')).toBe('2026-10-31T23:30');
    expect(fromLocalInputValue('', 'Asia/Riyadh')).toBeNull();
  });
});
