import { findLeak, LEAK_MIN_DEALS } from '../wave/leak';
import { periodRange } from '../periods';

const conversion = (count, dropped) => ({
  leak_stage_id: 2,
  rows: [
    { stage_id: 1, count: count + dropped, rate: null, dropped: null },
    { stage_id: 2, count, rate: 40, dropped },
  ],
});

describe('findLeak', () => {
  it('names the leaking stage when enough deals reached the stage before it', () => {
    expect(findLeak(conversion(4, 6))?.stage_id).toBe(2);
  });

  it('stays quiet when too few deals reached the stage before it', () => {
    expect(LEAK_MIN_DEALS).toBe(10);
    expect(findLeak(conversion(0, 2))).toBeNull();
  });

  it('stays quiet without a leak or without data', () => {
    expect(findLeak({ leak_stage_id: null, rows: [] })).toBeNull();
    expect(findLeak(undefined)).toBeNull();
  });
});

describe('periodRange last_30', () => {
  it('covers the 30 days up to today', () => {
    expect(periodRange('last_30', new Date(2026, 10, 1))).toEqual({
      from: '2026-10-03',
      to: '2026-11-01',
    });
  });
});
