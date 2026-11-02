// Custom (MyDesk): the home screen («لوحة التحكم») takes the account's /dashboard; the conversations live at /conversations
import { frontendURL } from 'dashboard/helper/URLHelper';
import HomePage from './HomePage.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/dashboard'),
    name: 'home_dashboard',
    meta: { permissions: ['administrator', 'agent', 'custom_role'] },
    // An old /dashboard?assignee=… link meant the conversations: send it there
    beforeEnter: to =>
      to.query.assignee
        ? { name: 'home', params: to.params, query: to.query }
        : true,
    component: HomePage,
  },
];
