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

describe('TrendLine dates', () => {
  it('puts the first date at the left end, where the line starts, even in RTL', () => {
    const wrapper = mount(TrendLine, {
      props: {
        lines: [{ id: 'won', label: 'Won', values: [1, 2], color: 'red' }],
        max: 2,
        start: '1 Nov',
        end: '30 Nov',
        ariaLabel: 'Sales',
        table: { headers: [], rows: [] },
      },
    });
    const row = wrapper.find('[data-testid="trend-axis"]');
    expect(row.attributes('dir')).toBe('ltr');
    expect(row.text().indexOf('1 Nov')).toBeLessThan(
      row.text().indexOf('30 Nov')
    );
  });
});

describe('TrendLine scale', () => {
  it("shows the top of the scale and each line's latest value", () => {
    const wrapper = mount(TrendLine, {
      props: {
        lines: [
          {
            id: 'response',
            label: 'Minutes',
            values: [4, 12, 9, null],
            color: 'red',
          },
        ],
        max: 12,
        format: value => `${value} min`,
        ariaLabel: 'Average first response',
        table: { headers: [], rows: [] },
      },
    });
    expect(wrapper.find('[data-testid="trend-max"]').text()).toBe('12 min');
    expect(wrapper.find('[data-testid="trend-axis"]').text()).toContain(
      '9 min'
    );
  });

  it('reads a dashed line that runs ahead (a target) on the last day the solid lines reach', () => {
    const wrapper = mount(TrendLine, {
      props: {
        lines: [
          {
            id: 'target',
            label: 'Target',
            values: [10, 20, 30, 40],
            color: 'grey',
            dashed: true,
          },
          {
            id: 'won',
            label: 'Won',
            values: [0, 5, null, null],
            color: 'teal',
          },
        ],
        max: 40,
        format: value => `${value} SAR`,
        ariaLabel: 'Won against target',
        table: { headers: [], rows: [] },
      },
    });
    const axis = wrapper.find('[data-testid="trend-axis"]').text();
    expect(axis).toContain('Target · 20 SAR');
    expect(axis).toContain('Won · 5 SAR');
    expect(axis).not.toContain('40 SAR');
  });
});
