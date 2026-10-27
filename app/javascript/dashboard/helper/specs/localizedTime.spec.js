import { dayLabel, messageDateTime, shortTimeAgo } from '../localizedTime';

describe('dayLabel', () => {
  const now = new Date(2026, 9, 28, 12, 0);
  const labels = { today: 'اليوم', yesterday: 'أمس' };
  const at = (year, month, day) =>
    new Date(year, month, day, 9).getTime() / 1000;

  it('names today and yesterday', () => {
    expect(dayLabel(at(2026, 9, 28), 'ar', labels, now)).toBe('اليوم');
    expect(dayLabel(at(2026, 9, 27), 'ar', labels, now)).toBe('أمس');
  });

  it('uses the weekday within the past week', () => {
    // 24 October 2026 is a Saturday
    expect(dayLabel(at(2026, 9, 24), 'ar', labels, now)).toBe('السبت');
  });

  it('adds the date for older days, and the year for earlier years', () => {
    expect(dayLabel(at(2026, 8, 10), 'ar', labels, now)).toContain('سبتمبر');
    expect(dayLabel(at(2025, 8, 10), 'ar', labels, now)).toMatch(/2025/);
    expect(dayLabel(at(2025, 8, 10), 'ar', labels, now)).not.toMatch(/[٠-٩]/);
  });
});

describe('localizedTime', () => {
  const now = new Date('2026-10-28T12:00:00Z').getTime();
  const secondsAgo = seconds => now / 1000 - seconds;

  describe('shortTimeAgo', () => {
    it('reads «الآن» under a minute', () => {
      expect(shortTimeAgo(secondsAgo(30), now)).toBe('الآن');
    });

    it('uses the largest whole unit', () => {
      expect(shortTimeAgo(secondsAgo(5 * 60), now)).toBe('5 د');
      expect(shortTimeAgo(secondsAgo(79 * 60), now)).toBe('1 س');
      expect(shortTimeAgo(secondsAgo(3 * 86400), now)).toBe('3 ي');
      expect(shortTimeAgo(secondsAgo(45 * 86400), now)).toBe('1 ش');
      expect(shortTimeAgo(secondsAgo(800 * 86400), now)).toBe('2 سنة');
    });

    it('never goes negative for clock skew', () => {
      expect(shortTimeAgo(secondsAgo(-20), now)).toBe('الآن');
    });
  });

  describe('messageDateTime', () => {
    it('writes the Arabic month with Latin digits and no year this year', () => {
      const text = messageDateTime(secondsAgo(3600), 'ar', new Date(now));
      expect(text).toContain('أكتوبر');
      expect(text).toMatch(/28/);
      expect(text).not.toMatch(/2026/);
      expect(text).not.toMatch(/[٠-٩]/);
    });

    it('adds the year for an older message', () => {
      const lastYear = secondsAgo(400 * 86400);
      expect(messageDateTime(lastYear, 'ar', new Date(now))).toMatch(/2025/);
    });
  });
});
