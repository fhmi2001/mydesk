import { mount } from '@vue/test-utils';
import DealBadge from '../DealBadge.vue';

const state = vi.hoisted(() => {
  // eslint-disable-next-line global-require
  const { reactive } = require('vue');
  return reactive({ enabled: true, badges: {} });
});

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ({
    get value() {
      return state.enabled;
    },
  }),
}));
vi.mock('../dealBadges', () => ({
  badges: state.badges,
  requestBadge: vi.fn(),
}));
vi.mock('dashboard/routes/dashboard/crm/shared/useCrmFormat', () => ({
  useCrmFormat: () => ({ compactMoney: cents => `${cents / 100} ر.س` }),
}));

describe('DealBadge', () => {
  beforeEach(() => {
    state.enabled = true;
    Object.keys(state.badges).forEach(key => delete state.badges[key]);
  });

  it("shows the stage of the contact's biggest open deal and the total", () => {
    state.badges['5'] = {
      count: 1,
      total_cents: 500000,
      currency: 'SAR',
      stage: { name: 'تفاوض', color: '#f59e0b' },
    };
    const wrapper = mount(DealBadge, { props: { contactId: 5 } });
    expect(wrapper.text()).toContain('تفاوض');
    expect(wrapper.text()).toContain('5000 ر.س');
    expect(
      wrapper.find('[data-testid="deal-badge-dot"]').attributes('style')
    ).toContain('background');
  });

  it('says how many when there are several', () => {
    state.badges['5'] = {
      count: 3,
      total_cents: 100,
      currency: 'SAR',
      stage: { name: 'مؤهل', color: '#60a5fa' },
    };
    const wrapper = mount(DealBadge, { props: { contactId: 5 } });
    expect(wrapper.text()).toContain('CRM.BADGE.MORE');
  });

  it('shows nothing without an open deal, or when the Sales section is off', () => {
    expect(mount(DealBadge, { props: { contactId: 9 } }).html()).toBe(
      '<!--v-if-->'
    );
    state.enabled = false;
    state.badges['5'] = { count: 1, total_cents: 1, stage: { name: 'x' } };
    expect(mount(DealBadge, { props: { contactId: 5 } }).html()).toBe(
      '<!--v-if-->'
    );
  });
});
