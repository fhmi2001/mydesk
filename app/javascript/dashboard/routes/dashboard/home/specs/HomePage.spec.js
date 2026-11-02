import { computed, ref } from 'vue';
import { flushPromises, mount, RouterLinkStub } from '@vue/test-utils';
import HomePage from '../HomePage.vue';
import { loadAgentHome, loadManagerHome } from '../homeData';

const role = ref('agent');
vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin: computed(() => role.value === 'administrator') }),
}));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn(() => Promise.resolve()) }),
  useMapGetter: key =>
    ({
      'crm/status/isEnabled': ref(true),
      'crm/status/getUIFlags': ref({ hasFetched: true }),
      getCurrentUser: ref({ id: 1, name: 'Ahmed Ali' }),
      getCurrentAccountId: ref(1),
    })[key] || ref(null),
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountScopedRoute: (name, params, query) => ({ name, params, query }),
  }),
}));
vi.mock('../homeData', () => ({
  loadAgentHome: vi.fn(),
  loadManagerHome: vi.fn(),
}));

const emptyAgent = {
  meta: { meta: { mine_count: 0 } },
  conversations: { data: { payload: [] } },
  tasks: { totals: { today_count: 0 }, rows: [] },
  deals: { rows: [] },
  quota: { totals: { target_cents: 0, attainment: null } },
};

const mountPage = () =>
  mount(HomePage, {
    global: {
      stubs: { RouterLink: RouterLinkStub, ActionBar: true, Spinner: true },
    },
  });

beforeEach(() => {
  vi.clearAllMocks();
  loadAgentHome.mockResolvedValue(emptyAgent);
  loadManagerHome.mockResolvedValue({
    meta: { meta: { unassigned_count: 2, all_count: 5 } },
    waiting: { data: { payload: [] } },
    summary: null,
    summaryYesterday: null,
    csat: null,
    quota: null,
    forecast: null,
    conversion: null,
    stale: null,
    lateTasks: null,
  });
});

describe('HomePage', () => {
  it('shows the manager layout to an administrator', async () => {
    role.value = 'administrator';
    const wrapper = mountPage();
    await flushPromises();
    expect(loadManagerHome).toHaveBeenCalledWith({ crmEnabled: true });
    expect(loadAgentHome).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('HOME.NEEDS_YOU');
  });

  it('shows the employee layout to an agent', async () => {
    role.value = 'agent';
    const wrapper = mountPage();
    await flushPromises();
    expect(loadAgentHome).toHaveBeenCalledWith({ crmEnabled: true });
    expect(wrapper.text()).toContain('HOME.WAITING_FOR_YOU');
  });

  it('hides the target tile when the employee has no target', async () => {
    role.value = 'agent';
    const wrapper = mountPage();
    await flushPromises();
    expect(wrapper.text()).not.toContain('HOME.TILES.MY_TARGET');
  });

  it('shows the target tile when the employee has one', async () => {
    role.value = 'agent';
    loadAgentHome.mockResolvedValue({
      ...emptyAgent,
      quota: { totals: { target_cents: 10000, attainment: 62 } },
    });
    const wrapper = mountPage();
    await flushPromises();
    expect(wrapper.text()).toContain('HOME.TILES.MY_TARGET');
  });

  it('says so when nothing waits', async () => {
    role.value = 'agent';
    const wrapper = mountPage();
    await flushPromises();
    expect(wrapper.text()).toContain('HOME.EMPTY');
  });
});

describe('HomePage when a list source fails', () => {
  it('says the list could not load instead of "nothing waiting"', async () => {
    role.value = 'agent';
    loadAgentHome.mockResolvedValue({ ...emptyAgent, conversations: null });
    const wrapper = mountPage();
    await flushPromises();
    expect(wrapper.text()).toContain('HOME.LIST_FAILED');
    expect(wrapper.text()).not.toContain('HOME.EMPTY');
    expect(wrapper.text()).not.toContain('HOME.WAITING_COUNT');
  });

  it('says so for the manager too', async () => {
    role.value = 'administrator';
    loadManagerHome.mockResolvedValue({
      meta: { meta: { unassigned_count: 2 } },
      waiting: null,
    });
    const wrapper = mountPage();
    await flushPromises();
    expect(wrapper.text()).toContain('HOME.LIST_FAILED');
  });
});

describe('HomePage charts', () => {
  it('shows the manager the support charts and the employee only the sales ones', async () => {
    role.value = 'administrator';
    const manager = mountPage();
    await flushPromises();
    expect(manager.text()).toContain('HOME.CHARTS.TRAFFIC');
    expect(manager.text()).toContain('HOME.CHARTS.LOAD');
    expect(manager.text()).toContain('HOME.CHARTS.PIPELINE');

    role.value = 'agent';
    const agent = mountPage();
    await flushPromises();
    expect(agent.text()).not.toContain('HOME.CHARTS.TRAFFIC');
    expect(agent.text()).not.toContain('HOME.CHARTS.LOAD');
    expect(agent.text()).toContain('HOME.CHARTS.PIPELINE');
    expect(agent.text()).toContain('HOME.CHARTS.WON_VS_TARGET');
  });

  it('shows the numbers strip with its comparison', async () => {
    role.value = 'administrator';
    const wrapper = mountPage();
    await flushPromises();
    expect(wrapper.text()).toContain('HOME.KPI.NEW_TODAY');
    expect(wrapper.text()).toContain('HOME.KPI.PIPELINE');
  });
});

describe('HomePage numbers in one place', () => {
  it('puts every manager number in the strip, grouped by support and sales', async () => {
    role.value = 'administrator';
    const wrapper = mountPage();
    await flushPromises();
    const strip = wrapper.find('[data-testid="home-kpis"]');
    [
      'HOME.TILES.OPEN',
      'HOME.TILES.FIRST_RESPONSE',
      'HOME.TILES.CSAT',
      'HOME.TILES.TEAM_TARGET',
      'HOME.SUPPORT_TODAY',
      'HOME.SALES_MONTH',
    ].forEach(label => expect(strip.text()).toContain(label));
  });

  it("puts the employee's tasks and target in the strip too", async () => {
    role.value = 'agent';
    loadAgentHome.mockResolvedValue({
      ...emptyAgent,
      quota: { totals: { target_cents: 10000, attainment: 62 } },
    });
    const wrapper = mountPage();
    await flushPromises();
    const strip = wrapper.find('[data-testid="home-kpis"]');
    expect(strip.text()).toContain('HOME.TILES.TASKS_TODAY');
    expect(strip.text()).toContain('HOME.TILES.MY_TARGET');
  });
});

describe('HomePage late conversations', () => {
  it("words the server's count of conversations waiting over an hour", async () => {
    role.value = 'administrator';
    loadManagerHome.mockResolvedValue({
      meta: { meta: { unassigned_count: 0 } },
      waiting: { late_count: 3 },
    });
    const wrapper = mountPage();
    await flushPromises();
    expect(wrapper.text()).toContain('HOME.LINES.WAITING_LONG.other');
  });
});
