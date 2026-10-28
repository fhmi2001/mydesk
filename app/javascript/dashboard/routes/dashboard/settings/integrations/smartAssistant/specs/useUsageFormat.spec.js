import { sumTotals, useUsageFormat } from '../useUsageFormat';

vi.mock('vue-i18n', async () => {
  const { ref } = await import('vue');
  return { useI18n: () => ({ locale: ref('en') }) };
});

describe('useUsageFormat', () => {
  const { formatUsd, formatSar } = useUsageFormat();

  it('keeps fractions of a cent readable instead of rounding them to zero', () => {
    expect(formatUsd(0.0000584)).toBe('$0.000058');
    expect(formatUsd(0)).toBe('$0.00');
    expect(formatUsd(12.3456)).toBe('$12.35');
  });

  it('converts dollars to riyals at the 3.75 peg', () => {
    // Intl puts a no-break space between the code and the amount
    expect(formatSar(2)).toMatch(/^SAR\s7\.50$/);
  });
});

describe('sumTotals', () => {
  it('adds up the per-kind totals and skips missing kinds', () => {
    const totals = sumTotals({
      reply: {
        input_tokens: 900,
        output_tokens: 60,
        cached_tokens: 0,
        cost: '0.00012',
        calls: 1,
      },
      test: {
        input_tokens: 100,
        output_tokens: 40,
        cached_tokens: 50,
        cost: '0.00003',
        calls: 2,
      },
      knowledge: undefined,
    });

    expect(totals).toMatchObject({
      input_tokens: 1000,
      output_tokens: 100,
      cached_tokens: 50,
      calls: 3,
    });
    expect(totals.cost).toBeCloseTo(0.00015);
  });
});
