// Custom (MyDesk): the conversation panel's deals & tasks
import { flushPromises, shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ContactCrmSection from '../ContactCrmSection.vue';

vi.mock('dashboard/api/crm', () => ({
  crmContactSummaryAPI: { get: vi.fn() },
}));
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountScopedRoute: name => ({ name }) }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

import { crmContactSummaryAPI } from 'dashboard/api/crm';

const pipeline = {
  id: 1,
  currency: 'SAR',
  stages: [
    { id: 10, name: 'Lead', kind: 'open' },
    { id: 11, name: 'Won', kind: 'won' },
    { id: 12, name: 'Lost', kind: 'lost' },
  ],
};

const makeStore = move =>
  createStore({
    modules: {
      crm: {
        namespaced: true,
        modules: {
          status: {
            namespaced: true,
            getters: { isEnabled: () => true, timezone: () => 'Asia/Riyadh' },
          },
          pipelines: {
            namespaced: true,
            getters: { all: () => [pipeline] },
            actions: { fetch: vi.fn() },
          },
          deals: {
            namespaced: true,
            getters: { getUIFlags: () => ({}) },
            actions: { move, create: vi.fn() },
          },
          tasks: {
            namespaced: true,
            getters: { getUIFlags: () => ({}) },
            actions: { create: vi.fn(), complete: vi.fn() },
          },
        },
      },
    },
  });

const mountSection = async move => {
  crmContactSummaryAPI.get.mockResolvedValue({
    data: {
      deals: [
        {
          id: 5,
          title: 'Deal',
          pipeline_id: 1,
          stage_id: 10,
          amount_cents: 100,
          currency: 'SAR',
          lock_version: 2,
        },
      ],
      tasks: [
        { id: 7, title: 'For deal', deal: { id: 5 } },
        { id: 8, title: 'Loose', deal: null },
      ],
      closed_count: 0,
    },
  });
  const wrapper = shallowMount(ContactCrmSection, {
    props: {
      contactId: 3,
      contactName: 'Ali',
      conversationId: 9,
      assigneeId: 4,
    },
    global: { plugins: [makeStore(move)], mocks: { $t: k => k } },
  });
  await flushPromises();
  return wrapper;
};

describe('ContactCrmSection', () => {
  it('groups tasks under their deal and keeps the others separate', async () => {
    const wrapper = await mountSection(vi.fn());
    const vm = wrapper.vm;
    expect(vm.tasksOf({ id: 5 }).map(t => t.id)).toEqual([7]);
    expect(vm.looseTasks.map(t => t.id)).toEqual([8]);
  });

  it('moves straight to an open or won stage with the deal lock version', async () => {
    const move = vi.fn().mockResolvedValue({});
    const wrapper = await mountSection(move);
    await wrapper.vm.onStageChange(wrapper.vm.deals[0], 11);
    await flushPromises();
    expect(move).toHaveBeenCalledWith(expect.anything(), {
      id: 5,
      stageId: 11,
      lostReason: undefined,
      lostNote: undefined,
      lockVersion: 2,
    });
  });

  it('asks for a reason before the lost stage and passes reason and note', async () => {
    const move = vi.fn().mockResolvedValue({});
    const wrapper = await mountSection(move);
    const open = vi.fn();
    wrapper.vm.$refs.lostDialog.open = open;
    wrapper.vm.$refs.lostDialog.close = vi.fn();
    wrapper.vm.onStageChange(wrapper.vm.deals[0], 12);
    expect(move).not.toHaveBeenCalled();
    expect(open).toHaveBeenCalled();
    wrapper.vm.onLostConfirm({ reason: 'Price', note: 'wanted 30%' });
    await flushPromises();
    expect(move).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        stageId: 12,
        lostReason: 'Price',
        lostNote: 'wanted 30%',
      })
    );
  });

  it('opens the task form with the deal already in its presets', async () => {
    const wrapper = await mountSection(vi.fn());
    let presetsAtOpen = null;
    wrapper.vm.$refs.taskForm.open = () => {
      presetsAtOpen = { ...wrapper.vm.taskPresets };
    };
    await wrapper.vm.openTaskFor(wrapper.vm.deals[0]);
    expect(presetsAtOpen).toMatchObject({
      deal_id: 5,
      deal_title: 'Deal',
      contact_id: 3,
      conversation_id: 9,
    });
  });
});
