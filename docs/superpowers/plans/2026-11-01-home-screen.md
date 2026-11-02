# MyDesk Home Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A role-based home screen (employee: "waiting for you now"; manager: "needs your attention") that every user lands on after login, with a quick-actions bar and the key numbers beside the list.

**Architecture:** A new Vue page under `routes/dashboard/home/` reads only existing APIs (Chatwoot conversations, reports summary, CSAT metrics; the Sales CRM tasks and reports). Pure functions build and rank the list; a loader fetches every source independently so one failure hides only its own part. The new page takes the URL `accounts/:id/dashboard` (where login already lands); the conversations page moves to `accounts/:id/conversations`, keeping its route name `home`.

**Tech Stack:** Vue 3 `<script setup>`, Vue Router, Vuex (`useMapGetter`), vue-i18n, Tailwind (`n-*` tokens), Vitest.

**Spec:** `docs/superpowers/specs/2026-11-01-home-screen-design.md`

## Global Constraints

- Every edit to an upstream Chatwoot file carries a `Custom (MyDesk)` comment; nothing under `enterprise/` changes.
- No new tables, columns, or backend endpoints.
- The new route is `accounts/:accountId/dashboard`, **name `home_dashboard`**, shown as «لوحة التحكم» / "Dashboard". The name `home` stays on the conversations page, whose path becomes `accounts/:accountId/conversations`; never navigate to conversations by path.
- An old `accounts/:id/dashboard?assignee=…` link redirects to `{ name: 'home', query }`.
- `routes/index.js` and `v3/helpers/AuthHelper.js` already land on `/dashboard`; they are not edited.
- Role comes from the account role: `useAdmin()` (`dashboard/composables/useAdmin.js`) → manager layout; otherwise employee layout.
- Sales items, numbers, buttons and team bars show only when `crm/status/isEnabled` is true.
- The employee list shows at most **8** items; a conversation is "over an hour" when `waiting_since` is older than **60 minutes**; stale deals use the stale report's default (14 days).
- Days are Riyadh days: `riyadhToday()` / `periodRange()` from `routes/dashboard/crm/reports/periods.js`.
- Design follows `DESIGN.md`: violet (`n-brand`) only on the primary "new conversation" button; flat cards, no shadows; ruby only for late items; Tajawal 500 for headings, 700 only for big numbers; logical properties (`ms-`, `pe-`, `start-`).
- All copy in `i18n/locale/{ar,en}/home.json` under `HOME.*`.
- Commit only when the user asks; commit footer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Tests: `wsl.exe -d ubuntu -- sh -c 'cd ~/chatwoot && docker compose exec -T rails pnpm exec vitest run app/javascript/dashboard/routes/dashboard/home'`.

## Review Focus

1. A conversation with `waiting_since` null/0 (answered, or never waited) must not appear in "waiting for you" — test in Task 1.
2. CRM switched off: no sales request is sent at all (not just hidden) — test in Task 2.
3. One source fails (e.g. CSAT 500): the rest of the screen still renders and that tile shows the "could not load" line — test in Task 2.
4. An employee with no monthly target (`quota` row missing/target 0): the target tile is hidden, not "0%" — test in Task 1 (`agentTargetRate`).
5. An old bookmark `…/dashboard?assignee=unassigned` must open the unassigned conversations, not the new page — test in Task 4.

---

### Task 1: Ranking functions (`attention.js`)

**Files:**
- Create: `app/javascript/dashboard/routes/dashboard/home/attention.js`
- Test: `app/javascript/dashboard/routes/dashboard/home/specs/attention.spec.js`

**Interfaces:**
- Produces:
  - `MAX_ITEMS = 8`, `LATE_MINUTES = 60`
  - `agentItems({ conversations, tasks, deals, now }) -> Item[]` where
    - `conversations: [{ id, waiting_since /* epoch s or null */, meta: { sender: { name } }, last_non_activity_message?: { content } }]` (Chatwoot list payload)
    - `tasks: [{ id, title, due_at /* ISO */, overdue /* bool */ }]` (CRM task presenter)
    - `deals: [{ id, title, close_date /* YYYY-MM-DD */ }]` (closing report rows)
    - `Item = { kind: 'task_overdue'|'conversation'|'task_today'|'deal', id, title, detail, at: Date, urgent: boolean }`
  - `managerItems({ unassigned, waitingLong, leak, stale, lateTasks }) -> Line[]`
    - inputs: `unassigned: { count, oldestAt: Date|null }`, `waitingLong: { count }`, `leak: { name, rate } | null`, `stale: { count, amount }`, `lateTasks: { count, topName, topCount }`; any may be `null` (source failed or CRM off)
    - `Line = { kind: 'unassigned'|'waiting_long'|'leak'|'stale'|'late_tasks', count?, data }`
  - `agentTargetRate(quota, userId) -> number|null` — attainment 0..1 for that user from the quota report, `null` when no row or target ≤ 0.

- [ ] **Step 1: Write the failing tests** — `attention.spec.js`:
  - `agentItems orders overdue tasks, then conversations by oldest wait, then today's tasks, then deals by nearest close`: given one of each (plus two conversations waiting 25 and 8 minutes), expect kinds `['task_overdue','conversation','conversation','task_today','deal']` and the 25-minute conversation before the 8-minute one.
  - `agentItems skips conversations not waiting`: `waiting_since: null` and `0` produce no item.
  - `agentItems caps the list at 8`: 12 conversations → length 8.
  - `agentItems marks overdue tasks urgent`: `urgent === true` only on `task_overdue`, and on conversations waiting ≥ `LATE_MINUTES`.
  - `managerItems keeps the fixed order and drops zero counts`: `{ unassigned:{count:6}, waitingLong:{count:0}, leak:{name:'عرض السعر',rate:0.3}, stale:{count:8,amount:120000}, lateTasks:{count:5,topName:'سالم',topCount:3} }` → kinds `['unassigned','leak','stale','late_tasks']`.
  - `managerItems drops null sources`: all sales inputs `null` → only conversation lines.
  - `agentTargetRate returns null without a target`: no row → `null`; `target: 0` → `null`; `{ achieved: 62, target: 100 }` → `0.62`.

- [ ] **Step 2: Run, expect FAIL** — Run the Global test command. Expected: FAIL, `Failed to resolve import "../attention"`.

- [ ] **Step 3: Implement `attention.js`** — sort keys: kind rank (`task_overdue` 0, `conversation` 1, `task_today` 2, `deal` 3), then `at` ascending (`at` = due time, wait start, or close date). `detail` is raw data (minutes waited, days late, due time, close date) — the component formats it with i18n. Read the quota report row shape from `app/services/sales_crm/reports/quota.rb` for `agentTargetRate`.

- [ ] **Step 4: Run, expect PASS** — Global test command → all `attention.spec.js` tests pass.

- [ ] **Step 5: Commit checkpoint** (only if the user asked) — `feat(home): rank what is waiting for the employee and the manager`.

---

### Task 2: Data loader (`homeData.js`)

**Files:**
- Create: `app/javascript/dashboard/routes/dashboard/home/homeData.js`
- Test: `app/javascript/dashboard/routes/dashboard/home/specs/homeData.spec.js`

**Interfaces:**
- Consumes: `ConversationAPI` (`dashboard/api/inbox/conversation.js`: `meta`, `get`), `ReportsAPI.getSummary(since, until)` (`dashboard/api/reports.js`), `CSATReportsAPI.getMetrics({ from, to })` (`dashboard/api/csatReports.js`), `crmReportsAPI.report(key, params)` and `crmTasksAPI.get({ scope })` (`dashboard/api/crm`); `periodRange`, `riyadhToday` (`crm/reports/periods.js`), `forwardRange` (`crm/reports/wave/reportCatalog.js`), `findLeak` (`crm/reports/wave/leak.js`).
- Produces:
  - `riyadhDayBounds(day: Date) -> { since: number, until: number }` — epoch seconds of that calendar day 00:00–23:59:59 at `+03:00`.
  - `loadAgentHome({ crmEnabled }) -> Promise<{ meta, conversations, tasks, deals, quota }>`
  - `loadManagerHome({ crmEnabled }) -> Promise<{ meta, waiting, summary, summaryYesterday, csat, quota, forecast, conversion, stale, lateTasks }>`
  - Every value is the response data, or `null` when that request failed (or was not sent because CRM is off).

Sources (period values as in the existing `DashboardPage.vue`):

| key | call |
|---|---|
| `meta` | `ConversationAPI.meta({ status: 'open' })` |
| `conversations` (agent) | `ConversationAPI.get({ status: 'open', assigneeType: 'me', sortBy: 'waiting_since_asc', page: 1 })` |
| `waiting` (manager) | same with `assigneeType: 'all'` |
| `tasks` | `crmReportsAPI.report('my_tasks', periodRange('month'))` |
| `deals` | `crmReportsAPI.report('closing', forwardRange('month'))` |
| `quota` | `crmReportsAPI.report('quota', forwardRange('month'))` |
| `forecast` | `crmReportsAPI.report('forecast', forwardRange('month'))` |
| `conversion` | `crmReportsAPI.report('conversion', periodRange('last_30'))` |
| `stale` | `crmReportsAPI.report('stale', {})` |
| `lateTasks` | `crmTasksAPI.get({ scope: 'overdue' })` (admins see every assignee's tasks) |
| `summary` / `summaryYesterday` | `ReportsAPI.getSummary(...riyadhDayBounds(today|yesterday))` |
| `csat` | `CSATReportsAPI.getMetrics({ from, to })` with today's bounds |

- [ ] **Step 1: Write the failing tests** — mock the four API modules with `vi.mock`:
  - `riyadhDayBounds gives the Riyadh day in epoch seconds`: `riyadhDayBounds(new Date(2026, 10, 1))` → `{ since: 1793480400, until: 1793566799 }` (2026-10-31T21:00:00Z … 2026-11-01T20:59:59Z).
  - `loadManagerHome keeps the rest when one source fails`: `getMetrics` rejects → result `csat === null`, `meta` and `summary` set.
  - `loadAgentHome sends no sales request when CRM is off`: `crmEnabled: false` → `crmReportsAPI.report` and `crmTasksAPI.get` not called; `tasks`, `deals`, `quota` are `null`.
  - `loadAgentHome asks for my open conversations by longest wait`: `ConversationAPI.get` called with `expect.objectContaining({ assigneeType: 'me', sortBy: 'waiting_since_asc', status: 'open' })`.

- [ ] **Step 2: Run, expect FAIL** — Expected: FAIL, unresolved import `../homeData`.

- [ ] **Step 3: Implement `homeData.js`** — build the request list for the role, run with `Promise.allSettled`, map rejected → `null`, fulfilled → `response.data`. Check each API's actual argument names in its file before calling (the table gives intent; the file wins).

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit checkpoint** (only if asked) — `feat(home): load the home screen's sources independently`.

---

### Task 3: The page, its parts and copy

**Files:**
- Create: `routes/dashboard/home/HomePage.vue`, `ActionBar.vue`, `AttentionList.vue`, `TeamBars.vue`, `home.routes.js`
- Create: `app/javascript/dashboard/i18n/locale/ar/home.json`, `app/javascript/dashboard/i18n/locale/en/home.json`
- Modify: `app/javascript/dashboard/i18n/locale/{ar,en}/index.js` (import `home.json`, spread it; `Custom (MyDesk)`)
- Modify: `app/javascript/dashboard/routes/dashboard/dashboard.routes.js` (spread `homeRoutes.routes`; `Custom (MyDesk)`)
- Test: `routes/dashboard/home/specs/HomePage.spec.js`

**Interfaces:**
- Consumes: Task 1 (`agentItems`, `managerItems`, `agentTargetRate`, `LATE_MINUTES`), Task 2 (`loadAgentHome`, `loadManagerHome`), `NumberTile` (`crm/reports/wave/NumberTile.vue`, props `label`, `value`, `note`, `tone`), `RankedBars` (`crm/reports/wave/RankedBars.vue`) if its props fit, else `TeamBars` draws the bars itself.
- Produces: route `{ path: frontendURL('accounts/:accountId/dashboard'), name: 'home_dashboard', meta: { permissions: ['administrator', 'agent', 'custom_role'] }, component: HomePage }` (the path is taken over from the conversations route in Task 4; until then register it after the conversation routes and test via its name).

Parts:
- `ActionBar.vue` — buttons per spec §4.1. "New conversation" wraps `ComposeConversation` (`components-next/NewConversation/ComposeConversation.vue`, `#trigger` slot) as the sidebar does. "Contact" opens `CreateNewContactDialog` the way `ContactListHeaderWrapper.vue` does (`dialogRef.open()`, then `contacts/create`). "Task" opens `TaskForm` (`crm/tasks/TaskForm.vue`) and submits as `TasksPage.vue`'s `onSubmit` does. "Deal" → `{ name: 'crm_deal_new' }`. "Campaign" (manager only) → the campaigns page.
- `AttentionList.vue` — props `items` (Item[] or Line[]), `variant: 'agent'|'manager'`; each row is a `router-link`:
  - conversation → `{ name: 'inbox_conversation', params: { conversation_id: id } }`
  - task → `{ name: 'crm_tasks' }`; deal → `{ name: 'crm_deal', params: { dealId } }`
  - unassigned → `{ name: 'home', query: { assignee: 'unassigned' } }`; waiting_long → `{ name: 'home', query: { assignee: 'all' } }`
  - leak / stale / late_tasks → `{ name: 'crm_report', params: { reportKey: 'conversion'|'stale'|'my_tasks' } }`
  - Empty → `HOME.EMPTY` with a link to the conversations.
- `HomePage.vue` — `useAdmin()` picks the layout; `crm/status/fetch` first if not fetched (as `DashboardPage.vue` does); loading skeletons; a failed source shows `HOME.LOAD_FAILED` in its own card; below `md` one column and `pb-20 md:pb-0` like the report pages.

- [ ] **Step 1: Write the failing tests** — `HomePage.spec.js` (mount with `vi.mock('../homeData')`, stub router-link and child dialogs):
  - `shows the manager layout to an administrator`: `useAdmin` → true → `loadManagerHome` called, `HOME.NEEDS_YOU` heading present.
  - `shows the employee layout to an agent`: → `loadAgentHome` called, `HOME.WAITING_FOR_YOU` present.
  - `hides the target tile when the employee has no target`: quota with no row for the user → no `HOME.MY_TARGET` text.
  - `shows the empty line when nothing waits`: all lists empty → `HOME.EMPTY` present.

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement the parts, route and both `home.json` files** — Arabic copy from the approved mockups: «صباح الخير، {name}» / «مساء الخير، {name}», «عندك {n} أشياء تنتظرك اليوم», «{n} أشياء تحتاج تدخّلك اليوم», «ينتظرك الآن», «يحتاج تدخّلك», «لا شيء ينتظرك الآن», «تعذّر تحميل هذا الجزء», and the line/tile labels in spec §4.2–4.3. English mirrors them.

- [ ] **Step 4: Run, expect PASS**; then ESLint: `docker compose exec -T rails pnpm exec eslint --ext .js,.vue app/javascript/dashboard/routes/dashboard/home` → 0 errors.

- [ ] **Step 5: Commit checkpoint** (only if asked) — `feat(home): role-based home page`.

---

### Task 4: `/dashboard` becomes the home screen, conversations move, sidebar entry

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/conversation/conversation.routes.js` — the `name: 'home'` route's path `accounts/:accountId/dashboard` → `accounts/:accountId/conversations`. `Custom (MyDesk)`.
- Modify: `routes/dashboard/home/home.routes.js` — `beforeEnter`: when `to.query.assignee` is set, `next({ name: 'home', params: to.params, query: to.query })` (old conversation bookmarks); else `next()`.
- Modify: `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` — first menu item `{ name: 'Dashboard', label: t('HOME.TITLE') /* «لوحة التحكم» / "Dashboard" */, icon: 'i-lucide-layout-dashboard', to: accountScopedRoute('home_dashboard') }`. `Custom (MyDesk)`.
- Modify: `HomePage.vue` — document title `HOME.TITLE` via the page header the CRM pages use.
- Test: `routes/dashboard/home/specs/home.routes.spec.js`.

- [ ] **Step 1: Write the failing tests** (`createRouter` with `createMemoryHistory`, the conversation routes and the home routes):
  - `opens the home screen at /dashboard`: `router.resolve('/app/accounts/1/dashboard').name === 'home_dashboard'`.
  - `opens the conversations at /conversations`: `router.resolve('/app/accounts/1/conversations').name === 'home'`.
  - `keeps a conversation's own link`: `/app/accounts/1/conversations/42` → `inbox_conversation`.
  - `sends an old assignee bookmark to the conversations`: push `/app/accounts/1/dashboard?assignee=unassigned` → current route name `home`, query `assignee: 'unassigned'`.

- [ ] **Step 2: Run, expect FAIL** (`/conversations` resolves to nothing; `/dashboard` resolves to `home`).

- [ ] **Step 3: Make the edits.** Then `grep -rn "accounts/:accountId/dashboard\|/dashboard\`" app/javascript --include=*.js --include=*.vue` and confirm the only path-based uses left are the login redirects (which should now land on the home screen).

- [ ] **Step 4: Run all home specs plus `routes/index.spec.js`, expect PASS.**

- [ ] **Step 5: Commit checkpoint** (only if asked) — `feat(home): the dashboard URL opens the home screen; conversations move to /conversations`.

---

### Task 5: Check it in the browser

- [ ] Sign in (the user does) as an administrator of account 2 (CRM on): the landing URL is `/app/accounts/2/dashboard`, the sidebar's first item reads «لوحة التحكم», the conversation views open `/conversations?assignee=…`, the manager layout shows, each line opens its target, "New conversation" opens the compose dialog.
- [ ] As an agent: employee layout; the list order matches Task 1; a conversation opens on click.
- [ ] An account with CRM off: no sales lines, tiles, buttons or team bars, and no `/crm/` request in the network log.
- [ ] 375px width: one column, the last item clears the floating menu button.
- [ ] Run `impeccable` detector on `routes/dashboard/home` and fix anything it flags.
- [ ] Full Vitest run for `routes/dashboard/crm`, `routes/dashboard/home`, `helper` stays green.
