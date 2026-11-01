import ar from 'dashboard/i18n/locale/ar/home.json';
import en from 'dashboard/i18n/locale/en/home.json';

// The counted copy goes through crmPlural: Arabic needs every form, English one and other
const PLURALS = [
  'WAITING_COUNT',
  'NEEDS_YOU_COUNT',
  'LATE_DAYS',
  'LINES.UNASSIGNED',
  'LINES.WAITING_LONG',
  'LINES.STALE',
  'LINES.LATE_TASKS',
];
const at = (copy, path) =>
  path.split('.').reduce((node, key) => node?.[key], copy.HOME);

describe('home copy', () => {
  it.each(PLURALS)('has every Arabic plural form of %s', key => {
    expect(Object.keys(at(ar, key)).sort()).toEqual(
      ['few', 'many', 'one', 'other', 'two', 'zero'].sort()
    );
  });

  it.each(PLURALS)('has the English plural forms of %s', key => {
    expect(Object.keys(at(en, key)).sort()).toEqual(['one', 'other']);
  });
});
