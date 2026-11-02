import { compareKpi } from '../kpi';

describe('compareKpi', () => {
  it('has nothing to say about an average with nothing to average today', () => {
    expect(
      compareKpi(0, 600, { average: true, lowerIsBetter: true })
    ).toBeNull();
  });

  it('compares a count like for like', () => {
    expect(compareKpi(12, 10)).toEqual({ label: '▲ 20%', tone: 'up' });
  });

  it('marks a slower average as worse', () => {
    expect(
      compareKpi(900, 600, { average: true, lowerIsBetter: true })
    ).toEqual({ label: '▲ 50%', tone: 'down' });
  });

  it('has nothing to compare against without a previous figure', () => {
    expect(compareKpi(5, null)).toBeNull();
  });
});
