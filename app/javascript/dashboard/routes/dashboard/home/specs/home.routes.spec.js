import { createRouter, createMemoryHistory } from 'vue-router';
import conversation from '../../conversation/conversation.routes';
import { routes as homeRoutes } from '../home.routes';

vi.mock('../HomePage.vue', () => ({ default: { template: '<div />' } }));
vi.mock('../../conversation/ConversationView.vue', () => ({
  default: { template: '<div />' },
}));

const makeRouter = () =>
  createRouter({
    history: createMemoryHistory(),
    routes: [...homeRoutes, ...conversation.routes],
  });

describe('home routes', () => {
  it('opens the home screen at /dashboard', () => {
    expect(makeRouter().resolve('/app/accounts/1/dashboard').name).toBe(
      'home_dashboard'
    );
  });

  it('opens the conversations at /conversations', () => {
    expect(makeRouter().resolve('/app/accounts/1/conversations').name).toBe(
      'home'
    );
  });

  it("keeps a conversation's own link", () => {
    expect(makeRouter().resolve('/app/accounts/1/conversations/42').name).toBe(
      'inbox_conversation'
    );
  });

  it('sends an old assignee bookmark to the conversations', async () => {
    const router = makeRouter();
    await router.push('/app/accounts/1/dashboard?assignee=unassigned');
    expect(router.currentRoute.value.name).toBe('home');
    expect(router.currentRoute.value.query).toEqual({ assignee: 'unassigned' });
  });
});
