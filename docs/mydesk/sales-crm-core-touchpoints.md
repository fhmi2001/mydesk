# Sales CRM (المبيعات): where it touches Chatwoot's own files

Everything else lives in its own folders (`app/models/sales_crm*`, `app/services/sales_crm/`, `app/policies/sales_crm/`,
`app/jobs/sales_crm/`, `app/controllers/api/v1/accounts/crm/`, `app/controllers/super_admin/crm_overview_controller.rb`,
`app/views/super_admin/crm_overview/`, `config/locales/sales_crm.*.yml`, `app/javascript/dashboard/routes/dashboard/crm/`,
`app/javascript/dashboard/routes/dashboard/conversation/crm/`, `app/javascript/dashboard/store/modules/crm/`,
`app/javascript/dashboard/api/crm/`, `app/javascript/dashboard/helper/crmFormat.js`, `app/javascript/dashboard/i18n/locale/*/crm.json`,
`spec/**/sales_crm*`, `spec/controllers/api/v1/accounts/crm/`, `spec/i18n/sales_crm_parity_spec.rb`).

Every edit below is marked `Custom (MyDesk)` on the line or block. Re-check this list after each Chatwoot upgrade:
`git grep -n "Custom (MyDesk)" -- <file>` shows the exact lines.

| File | What was added | Why |
|---|---|---|
| `config/features.yml` | `sales_crm` flag (`feature_flags_ext_1`, off by default) | Per-account on/off switch, shown on the Super Admin account page |
| `spec/models/account_spec.rb` | `feature_sales_crm: 1 << 15` in the ext_1 mapping | The upstream spec lists every flag |
| `app/models/account.rb` | `include SalesCrmAccount` | CRM associations and settings (the concern is ours: `app/models/concerns/sales_crm_account.rb`) |
| `app/models/notification.rb` | `crm_task_due: 20` in `NOTIFICATION_TYPES`; a branch in `push_message_title` | Task reminders in the bell / push |
| `config/locales/en.yml`, `config/locales/ar.yml` | `notifications.notification_title.crm_task_due` | Reminder title |
| `config/schedule.yml` | `sales_crm_task_reminder_job` (*/5 min), `sales_crm_purge_discarded_deals_job` (daily) | Reminders; purge of deals deleted > 30 days ago |
| `config/routes.rb` | `namespace :crm` under `api/v1/accounts/:account_id`; three `super_admin/crm_overview` routes | The CRM API and the Super Admin page |
| `config/initializers/sales_crm.rb` (ours) | prepends `SalesCrm::ContactMergePatch` into `ContactMergeAction` and `SalesCrm::AgentRemovalPatch` into `Agents::DestroyJob` | Deals/tasks follow a merged contact; a removed agent's open deals/tasks become unassigned. No edit to those two files. |
| `app/helpers/super_admin/navigation_helper.rb` | a Monitor entry «CRM»; `crm_overview` in `monitor_open?` | Sidebar link |
| `app/javascript/dashboard/featureFlags.js` | `SALES_CRM: 'sales_crm'` | Route gating |
| `app/javascript/dashboard/store/index.js` | `crm` module registered | Store |
| `app/javascript/dashboard/routes/dashboard/dashboard.routes.js` | `...crmRoutes.routes` | Pages |
| `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` | the «المبيعات» group (Deals, Tasks + overdue badge, Reports, Settings); `crm/status/fetch` on mount | Navigation |
| `app/javascript/dashboard/helper/actionCable.js` | `crm.deal_*` / `crm.task_*` events → `crm/deals/onRemoteChange`, `crm/tasks/onRemoteChange` | Live updates between agents |
| `app/javascript/dashboard/composables/useUISettings.js` | `{ name: 'crm' }` in `DEFAULT_CONVERSATION_SIDEBAR_ITEMS_ORDER` | The panel section appears for users with a saved order too |
| `app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue` | the `crm` accordion item rendering `ContactCrmSection` | Deals & tasks beside the conversation |
| `app/javascript/dashboard/routes/dashboard/contacts/pages/ContactManageView.vue` | a `CRM` tab rendering `ContactCrmSection` | Deals & tasks on the contact page |
| `app/javascript/dashboard/i18n/locale/{en,ar}/index.js` | `crm.json` import + spread | Translations |

## Removing the feature

1. Turn `sales_crm` off for every account (Super Admin > account > Features).
2. Delete the folders listed at the top, `app/models/concerns/sales_crm_account.rb`, `config/initializers/sales_crm.rb` and `docs/mydesk/sales-crm-core-touchpoints.md`.
3. Revert the marked lines in the table above.
4. Add a migration that drops `crm_activities, crm_notes, crm_tasks, crm_deals, crm_stages, crm_pipelines` (in that order).
