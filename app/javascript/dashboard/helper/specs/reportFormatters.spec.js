import {
  formatDuration,
  formatNumber,
  formatReportDate,
} from '../reportFormatters';

describe('reportFormatters', () => {
  it('writes Arabic durations with the two largest units', () => {
    expect(formatDuration(93, 'ar')).toBe('1 د 33 ث');
    expect(formatDuration(4 * 3600 + 21 * 60 + 5, 'ar')).toBe('4 س 21 د');
    expect(formatDuration(2 * 86400 + 3600, 'ar')).toBe('2 ي 1 س');
    expect(formatDuration(0, 'ar')).toBe('0 ث');
  });

  it('keeps the upstream format for other languages', () => {
    expect(formatDuration(93, 'en')).toBe('1 Min 33 Sec');
  });

  it('uses Western digits and Arabic month names', () => {
    const label = formatReportDate(new Date(2026, 9, 21), 'day', 'ar');
    expect(label).toMatch(/21/);
    expect(label).toMatch(/أكتوبر/);
    expect(formatNumber(1284, 'ar')).toBe('1,284');
  });
});
