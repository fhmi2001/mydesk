import { mount, RouterLinkStub } from '@vue/test-utils';
import AttentionList from '../AttentionList.vue';
import { periodRange } from '../../crm/reports/periods';

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountScopedRoute: (name, params, query) => ({ name, params, query }),
  }),
}));
vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  return { useMapGetter: () => ref(null) };
});

describe('AttentionList', () => {
  it('opens the conversion report on the same last 30 days as the leak line', () => {
    const wrapper = mount(AttentionList, {
      props: {
        title: 'Needs you',
        items: [{ kind: 'leak', data: { name: 'Won', rate: 30 } }],
      },
      global: { stubs: { RouterLink: RouterLinkStub } },
    });
    expect(wrapper.findComponent(RouterLinkStub).props('to')).toEqual({
      name: 'crm_report',
      params: { reportKey: 'conversion' },
      query: { period: 'custom', ...periodRange('last_30') },
    });
  });
});

describe('AttentionList late conversations', () => {
  const mountRow = urgent =>
    mount(AttentionList, {
      props: {
        title: 'Waiting',
        items: [
          {
            kind: 'conversation',
            id: 4,
            title: 'Sara',
            detail: { minutes: urgent ? 90 : 10 },
            urgent,
          },
        ],
      },
      global: { stubs: { RouterLink: RouterLinkStub } },
    });

  it('says a late conversation is late in words, not only in red', () => {
    const late = mountRow(true);
    expect(late.text()).toContain('HOME.WAITED_LATE');
    expect(late.find('.i-lucide-message-circle-warning').exists()).toBe(true);
  });

  it('keeps a recent one plain', () => {
    const recent = mountRow(false);
    expect(recent.text()).not.toContain('HOME.WAITED_LATE');
  });
});

describe('AttentionList counts', () => {
  const mountLines = items =>
    mount(AttentionList, {
      props: { title: 'Needs you', items },
      global: { stubs: { RouterLink: RouterLinkStub } },
    });

  it('words a count with its plural form', () => {
    const wrapper = mountLines([
      { kind: 'unassigned', count: 6, data: { count: 6 } },
    ]);
    expect(wrapper.text()).toContain('HOME.LINES.UNASSIGNED.other');
  });
});
