import { mount } from '@vue/test-utils';
import TrendLine from '../TrendLine.vue';

const mountLine = values =>
  mount(TrendLine, {
    props: {
      lines: [{ id: 'response', label: 'Minutes', values, color: 'red' }],
      max: 10,
      ariaLabel: 'Average first response',
      table: {
        headers: ['Day', 'Minutes'],
        rows: [
          ['Sat', '4'],
          ['Sun', '—'],
        ],
      },
    },
  });

describe('TrendLine', () => {
  it('leaves a gap at a missing day', () => {
    const wrapper = mountLine([4, null, 8, 6]);
    expect(wrapper.findAll('polyline')).toHaveLength(1);
    // The lone first day is a dot, not an invisible one-point line
    expect(wrapper.findAll('circle')).toHaveLength(1);
  });

  it('gives screen readers the values as a table', () => {
    const wrapper = mountLine([4, null]);
    const table = wrapper.find('table');
    expect(table.classes()).toContain('sr-only');
    expect(table.text()).toContain('Sat');
    expect(table.text()).toContain('4');
  });
});
