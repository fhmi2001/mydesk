import { mount } from '@vue/test-utils';
import ActionBar from '../ActionBar.vue';

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountScopedRoute: name => ({ name }) }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }));

describe('ActionBar', () => {
  it('gives every action a 44px touch target below md', () => {
    const wrapper = mount(ActionBar, {
      props: { crmEnabled: true, isAdmin: true },
      global: {
        stubs: {
          ComposeConversation: {
            template: '<div><slot name="trigger" /></div>',
          },
          CreateNewContactDialog: true,
          TaskForm: true,
        },
      },
    });
    const buttons = wrapper.findAll('button');
    expect(buttons).toHaveLength(5);
    buttons.forEach(button => {
      expect(button.classes()).toContain('max-md:!h-11');
    });
  });
});
