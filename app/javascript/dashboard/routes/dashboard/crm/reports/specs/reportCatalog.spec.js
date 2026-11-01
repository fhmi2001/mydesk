import { forwardRange, reportFor, REPORTS } from '../wave/reportCatalog';
import { periodRange } from '../periods';

describe('reportCatalog', () => {
  const now = new Date(2026, 9, 20); // 20 October 2026

  it('takes the whole month, next month or quarter for what is still to close', () => {
    expect(forwardRange('month', now)).toEqual({
      from: '2026-10-01',
      to: '2026-10-31',
    });
    expect(forwardRange('next_month', now)).toEqual({
      from: '2026-11-01',
      to: '2026-11-30',
    });
    expect(forwardRange('quarter', now)).toEqual({
      from: '2026-10-01',
      to: '2026-12-31',
    });
  });

  it('takes the whole year ahead, and the year so far behind', () => {
    expect(forwardRange('year', now)).toEqual({
      from: '2026-01-01',
      to: '2026-12-31',
    });
    expect(periodRange('year', now)).toEqual({
      from: '2026-01-01',
      to: '2026-10-20',
    });
  });

  it('crosses the year for next month in December', () => {
    expect(forwardRange('next_month', new Date(2026, 11, 5))).toEqual({
      from: '2027-01-01',
      to: '2027-01-31',
    });
  });

  it('lists the seven reports of wave A and falls back to the first', () => {
    expect(REPORTS.map(r => r.number)).toEqual([1, 2, 3, 4, 5, 6, 7]);
    expect(reportFor('nope').key).toBe('pipeline_by_stage');
  });
});
