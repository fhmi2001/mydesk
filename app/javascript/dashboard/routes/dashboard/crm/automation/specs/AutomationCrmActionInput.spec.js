import { mount } from '@vue/test-utils';
import AutomationCrmActionInput from '../AutomationCrmActionInput.vue';

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
  useMapGetter: () => ({
    value: [
      {
        id: 1,
        name: 'المبيعات',
        stages: [
          { id: 11, name: 'مؤهل', kind: 'open' },
          { id: 12, name: 'مكسوبة', kind: 'won' },
          { id: 13, name: 'خاسرة', kind: 'lost' },
        ],
      },
    ],
  }),
}));

const mountInput = (actionName, modelValue = {}) =>
  mount(AutomationCrmActionInput, { props: { actionName, modelValue } });
const lastEmitted = wrapper => wrapper.emitted('update:modelValue').at(-1)[0];

describe('AutomationCrmActionInput', () => {
  it('asks a deal suggestion for its title only', async () => {
    const wrapper = mountInput('suggest_crm_deal');
    expect(wrapper.findAll('input')).toHaveLength(1);
    expect(wrapper.find('select').exists()).toBe(false);
    await wrapper.find('input').setValue('طلب جملة');
    expect(lastEmitted(wrapper)).toEqual({ title: 'طلب جملة' });
  });

  it('asks a task for its title, kind and hours, keeping what is set', async () => {
    const wrapper = mountInput('create_crm_task', {
      title: 'اتصل',
      kind: 'task',
      hours: 2,
    });
    await wrapper.find('select').setValue('call');
    expect(lastEmitted(wrapper)).toEqual({
      title: 'اتصل',
      kind: 'call',
      hours: 2,
    });
  });

  it('offers every stage but the lost ones for a move', () => {
    const options = mountInput('move_crm_deal')
      .findAll('option')
      .map(option => option.text());
    expect(options.join(' ')).toContain('مؤهل');
    expect(options.join(' ')).toContain('مكسوبة');
    expect(options.join(' ')).not.toContain('خاسرة');
  });
});
