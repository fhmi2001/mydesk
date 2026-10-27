# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

MyDesk is a multi-tenant SaaS for Saudi e-commerce merchants. Each merchant is a company account with its own employees.

- **Merchant size:** launching with small and mid-size stores (about 1–10 employees, where the owner often answers customers or supervises a small team), and growing with them into larger stores with dedicated support teams, supervisors and performance targets.
- **Primary users, weighted equally:**
  - **The employee (موظف)** who answers customers all day in the conversations screen. Their job: reply fast and correctly across channels, see the customer's context (including store orders), and hand off cleanly.
  - **The store owner or manager** who follows performance, reports and campaigns. Their job: know how fast and how well customers are served, who on the team is doing what, and what campaigns and store events produce, then decide.
- **Platform operator (super admin):** runs the SaaS itself, configures shared provider keys (e.g. the Salla app, SMS gateways) and manages tenant accounts.

## Product Purpose

MyDesk's core goal is to bring **every communication channel and every customer conversation into one platform**. Instead of answering on each app separately, the merchant's team works one unified inbox across:

- WhatsApp, Facebook (Messenger), Instagram, X (Twitter) and Telegram
- Email, SMS and the website chat widget

Around that inbox: outbound SMS and live chat campaigns; store integrations that bring order events into the workspace; and, on the roadmap, AI bots, a lightweight native CRM, and an **automated call center** that answers incoming phone calls on its own, serves customers and takes their requests, with each call landing in the same platform as the other conversations.

Success means a merchant answers customers faster on every channel, never misses an order-related conversation or call, and can see the results of their team and campaigns without exporting data elsewhere.

## Positioning

Saudi-native rather than translated: Arabic-first with right-to-left layout as the default, Saudi mobile numbers handled natively (05… / 966…), local providers built in (Deewan SMS) and Saudi commerce platforms connected at the order level (Salla now; Zid and WooCommerce planned). It is white-label, so the platform can carry its own brand for its merchants.

## Operating Context

- Employees work in the conversations screen through the day, with traffic arriving from many channels at once (often WhatsApp-heavy, alongside Instagram, Facebook, X and others); owners check reports and campaigns periodically, also on mobile.
- Planned: incoming phone calls handled first by an automated call-center agent that answers, understands the request and records it, then hands over to an employee when needed; calls, their outcome and requests appear with the customer's other conversations.
- Campaigns: SMS campaigns to contact labels, typed numbers or Excel/CSV lists (Saudi mobiles cleaned and de-duplicated, 966 added), with a review step, per-number results, provider SMS/request ids and handset delivery status; live chat campaigns shown to website visitors by page URL and time on page.
- Store integration: a merchant connects their Salla store from Settings › Integrations (OAuth); order events (new order, status changes) arrive by signed webhooks and are kept per account, as the base for automatic WhatsApp/SMS order notifications.
- Reports cover conversations, employees, inboxes, labels, teams, CSAT and bots.

## Capabilities and Constraints

- Built on a fork of Chatwoot v4.19.1 (Rails 7.2, Vue 3, Tailwind, Sidekiq, Postgres). Custom work is marked `Custom (MyDesk)` in code so upstream updates can be merged.
- Chatwoot Enterprise is disabled for licensing (`DISABLE_ENTERPRISE`). Enterprise-only features (SLA policies, Captain AI, WhatsApp campaign analytics, some paywalled screens) are not available and must not be presented as working; replacements are built as MyDesk features.
- Default locale is Arabic. Terminology: «موظف» (employee), never «وكيل» (agent).
- Deewan SMS is outbound only (no inbound messages).
- Social channels (Facebook, Instagram, WhatsApp Cloud, X) each depend on the provider's app keys and approval; X support in this Chatwoot version still needs to be verified before it is presented as available.
- Salla is connected in OAuth Custom Mode; live stores require Salla's approval of the app, demo stores do not.
- Undecided: final product name (MyDesk is temporary); subscription plans and pricing; the AI bot provider; CRM scope; the telephony provider and voice AI for the automated call center.

## Brand Commitments

- Name: **MyDesk**, temporary; the final name will replace it, so the name must stay easy to swap (white-label).
- Voice: clear, simple, direct Modern Standard Arabic. Controls name their action; errors say what happened and how to recover.
- Identity so far: violet brand color and a temporary text logo; no final logo exists yet.

## Evidence on Hand

- No real customers, testimonials, case studies, usage statistics or benchmarks exist yet; none may be invented.
- The development account holds very little data (about 4 conversations, 25 messages, no CSAT responses), so data-heavy screens need realistic seeded demo data for design checks and must never present demo data as real.
- Integration assets: a temporary neutral Salla logo at `public/dashboard/images/integrations/salla.png` (to be replaced with Salla's official logo).

## Product Principles

1. **Arabic-first, Saudi-native.** Every screen is designed in Arabic and RTL first; local formats (numbers, dates, durations, Saudi mobiles) are native, not afterthoughts.
2. **Serve both the employee and the owner.** The employee needs speed and focus in conversations; the owner needs clear, decision-ready numbers. A screen knows which of them it serves.
3. **Grow with the merchant.** Work well for a store with one or two people, and scale to teams with supervisors and targets, without becoming complex for the small store.
4. **Honest data.** Never show a metric or feature that cannot work in this build; empty and low-data states explain what is missing and how to get it.
5. **Commerce in context.** Conversations, campaigns and reports connect to the merchant's store and orders; that link is the product's edge.
6. **One customer, one place.** Whatever the channel (message, social post, SMS or phone call), the customer and their history appear once, in the same platform; channels never fragment the team's view.
