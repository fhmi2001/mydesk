import { mount } from '@vue/test-utils';
import BarRows from '../BarRows.vue';

const mountRows = (rows, extra = {}) =>
  mount(BarRows, {
    props: {
      rows,
      label: row => String(row.value),
      barClass: 'bg-n-slate-9',
      noName: 'None',
      ...extra,
    },
  });

describe('BarRows', () => {
  it("shows a row's pipeline under its stage, and the whole name on hover", () => {
    const wrapper = mountRows([
      { id: 1, name: 'تم إرسال العرض', sub: 'المبيعات', value: 5 },
    ]);
    expect(wrapper.text()).toContain('المبيعات');
    expect(wrapper.find('[title="تم إرسال العرض"]').exists()).toBe(true);
  });

  it('colours each bar by its own rule when given one', () => {
    const wrapper = mountRows(
      [
        { id: 1, name: 'Sara', value: 16 },
        { id: 2, name: 'Nora', value: 3 },
      ],
      { barClassFor: row => (row.value > 10 ? 'bg-n-amber-9' : 'bg-n-slate-9') }
    );
    const fills = wrapper.findAll('[data-testid="bar-fill"]');
    expect(fills[0].classes()).toContain('bg-n-amber-9');
    expect(fills[1].classes()).toContain('bg-n-slate-9');
  });
});
