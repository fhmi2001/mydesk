// Custom (MyDesk)
import { deltaFor } from '../summaryDelta';
import { periodRange } from '../periods';

describe('summaryDelta', () => {
  it('formats rises and falls with arrows and colours', () => {
    expect(deltaFor(120, 100)).toEqual({ label: '▲ 20%', tone: 'up' });
    expect(deltaFor(80, 100)).toEqual({ label: '▼ 20%', tone: 'down' });
    expect(deltaFor(100, 100)).toEqual({ label: '0%', tone: 'flat' });
    expect(deltaFor(0, 0)).toEqual({ label: '', tone: 'flat' });
    expect(deltaFor(5, 0)).toEqual({ label: '▲ —', tone: 'up' });
  });

  it('flips the colour when lower is better', () => {
    expect(deltaFor(5, 10, true)).toEqual({ label: '▼ 50%', tone: 'up' });
    expect(deltaFor(10, 5, true)).toEqual({ label: '▲ 100%', tone: 'down' });
  });
});

describe('periodRange', () => {
  const now = new Date(2026, 9, 31); // Saturday 31 Oct 2026
  it('computes month, quarter, week (Saturday start) and today', () => {
    expect(periodRange('month', now)).toEqual({
      from: '2026-10-01',
      to: '2026-10-31',
    });
    expect(periodRange('quarter', now)).toEqual({
      from: '2026-10-01',
      to: '2026-10-31',
    });
    expect(periodRange('week', now)).toEqual({
      from: '2026-10-31',
      to: '2026-10-31',
    });
    expect(periodRange('today', now)).toEqual({
      from: '2026-10-31',
      to: '2026-10-31',
    });
    expect(periodRange('week', new Date(2026, 10, 2))).toEqual({
      from: '2026-10-31',
      to: '2026-11-02',
    });
  });
});
