// Custom (MyDesk): Sales CRM pages (المبيعات): deals, one deal, tasks, reports, settings
import { frontendURL } from 'dashboard/helper/URLHelper.js';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import CrmRouteView from './CrmRouteView.vue';
import DealsPage from './deals/DealsPage.vue';
import DealDetailPage from './deals/DealDetailPage.vue';
import TasksPage from './tasks/TasksPage.vue';
import ReportsPage from './reports/ReportsPage.vue';
import SalesSettingsPage from './settings/SalesSettingsPage.vue';

const everyone = {
  featureFlag: FEATURE_FLAGS.SALES_CRM,
  permissions: ['administrator', 'agent', 'custom_role'],
};

const adminOnly = {
  featureFlag: FEATURE_FLAGS.SALES_CRM,
  permissions: ['administrator'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/crm'),
    component: CrmRouteView,
    children: [
      { path: '', redirect: to => ({ name: 'crm_deals', params: to.params }) },
      {
        path: 'deals',
        name: 'crm_deals',
        meta: everyone,
        component: DealsPage,
      },
      {
        path: 'deals/:dealId',
        name: 'crm_deal',
        meta: everyone,
        component: DealDetailPage,
      },
      {
        path: 'tasks',
        name: 'crm_tasks',
        meta: everyone,
        component: TasksPage,
      },
      {
        path: 'reports',
        name: 'crm_reports',
        meta: everyone,
        component: ReportsPage,
      },
      {
        path: 'settings',
        name: 'crm_settings',
        meta: adminOnly,
        component: SalesSettingsPage,
      },
    ],
  },
];

export default { routes };
