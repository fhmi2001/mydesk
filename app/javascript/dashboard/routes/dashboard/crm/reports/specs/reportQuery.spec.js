import { toQuery, fromQuery } from '../wave/reportQuery';
import {
  periodRange,
  salesToday,
  setSalesTimeZone,
  dayBounds,
} from '../periods';
import { PAST_PERIODS } from '../wave/reportCatalog';

describe('toQuery', () => {
  it('writes only what is set, and the dates only for a custom period', () => {
    expect(
      toQuery({
        period: 'month',
        from: '2026-11-01',
        to: '2026-11-01',
        pipeline_id: 3,
        assignee_id: '',
        days: '',
        group_by: '',
      })
    ).toEqual({ period: 'month', pipeline_id: '3' });
    expect(
      toQuery({ period: 'custom', from: '2026-10-01', to: '2026-10-31' })
    ).toEqual({ period: 'custom', from: '2026-10-01', to: '2026-10-31' });
  });
});

describe('fromQuery', () => {
  it('reads ids as numbers and dates as dates', () => {
    expect(
      fromQuery({
        period: 'custom',
        from: '2026-10-01',
        to: '2026-10-31',
        assignee_id: '7',
        days: '14',
        group_by: 'lead_source',
      })
    ).toEqual({
      period: 'custom',
      from: '2026-10-01',
      to: '2026-10-31',
      assignee_id: 7,
      days: '14',
      group_by: 'lead_source',
    });
  });

  it('leaves out what does not read as a value', () => {
    expect(
      fromQuery({ from: 'yesterday', pipeline_id: 'x', group_by: '<b>' })
    ).toEqual({});
  });

  it('reads back what it wrote', () => {
    const state = { period: 'quarter', stage_id: 12, product_id: 4 };
    expect(fromQuery(toQuery(state))).toEqual(state);
  });
});

describe('last month', () => {
  it('is a past period covering the whole previous month', () => {
    expect(PAST_PERIODS).toContain('last_month');
    expect(periodRange('last_month', new Date(2026, 10, 1))).toEqual({
      from: '2026-10-01',
      to: '2026-10-31',
    });
    expect(periodRange('last_month', new Date(2026, 0, 15))).toEqual({
      from: '2025-12-01',
      to: '2025-12-31',
    });
  });
});

describe('salesToday', () => {
  afterEach(() => setSalesTimeZone(null));

  it("reads the calendar day in the account's time zone (Riyadh by default), not on the device", () => {
    // 23:30 UTC on 31 October is already 1 November in Riyadh (UTC+3)
    const day = salesToday(new Date(Date.UTC(2026, 9, 31, 23, 30)));
    expect([day.getFullYear(), day.getMonth(), day.getDate()]).toEqual([
      2026, 10, 1,
    ]);
    expect(periodRange('month', day)).toEqual({
      from: '2026-11-01',
      to: '2026-11-01',
    });
  });

  it('follows the time zone the account picked', () => {
    // 20:30 UTC on 31 October is 00:30 on 1 November in Dubai (UTC+4), still 23:30 on 31 October in Riyadh
    const instant = new Date(Date.UTC(2026, 9, 31, 20, 30));
    expect(salesToday(instant).getDate()).toBe(31);
    setSalesTimeZone('Asia/Dubai');
    expect(salesToday(instant).getDate()).toBe(1);
  });
});

describe('dayBounds', () => {
  afterEach(() => setSalesTimeZone(null));

  it("gives a calendar day in epoch seconds, in the account's time zone", () => {
    expect(dayBounds(new Date(2026, 10, 1))).toEqual({
      since: 1793480400,
      until: 1793566799,
    });
    setSalesTimeZone('Asia/Dubai');
    expect(dayBounds(new Date(2026, 10, 1))).toEqual({
      since: 1793480400 - 3600,
      until: 1793566799 - 3600,
    });
  });
});
