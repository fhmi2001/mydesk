---
name: MyDesk
description: The merchant's control room for every customer conversation, campaign and store event.
colors:
  brand-violet: "#7C3AED"
  violet-ink: "#5B21B6"
  violet-mist: "#EDE9FE"
  ink: "#1C2024"
  ink-muted: "#60646C"
  ink-faint: "#8B8D98"
  canvas: "#F7F7F7"
  surface: "#FEFEFE"
  card: "#FFFFFF"
  line-weak: "#EAEAEA"
  line-strong: "#E2E3E7"
  signal-teal: "#12A594"
  signal-teal-ink: "#008573"
  signal-ruby: "#E54666"
  signal-ruby-ink: "#CA244D"
  signal-amber: "#FFC53D"
  signal-amber-ink: "#AB6400"
  bubble-employee: "#DAECFF"
typography:
  headline:
    fontFamily: "Inter, Tajawal, -apple-system, system-ui, 'Segoe UI', Roboto, Tahoma, Arial, sans-serif"
    fontSize: "18px"
    fontWeight: 520
    lineHeight: "24px"
    letterSpacing: "-0.27px"
  title:
    fontFamily: "Inter, Tajawal, -apple-system, system-ui, 'Segoe UI', Roboto, Tahoma, Arial, sans-serif"
    fontSize: "16px"
    fontWeight: 500
    lineHeight: "24px"
    letterSpacing: "-0.27px"
  subtitle:
    fontFamily: "Inter, Tajawal, -apple-system, system-ui, 'Segoe UI', Roboto, Tahoma, Arial, sans-serif"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: "21px"
    letterSpacing: "-0.27px"
  body:
    fontFamily: "Inter, Tajawal, -apple-system, system-ui, 'Segoe UI', Roboto, Tahoma, Arial, sans-serif"
    fontSize: "14px"
    fontWeight: 420
    lineHeight: "21px"
    letterSpacing: "-0.28px"
  label:
    fontFamily: "Inter, Tajawal, -apple-system, system-ui, 'Segoe UI', Roboto, Tahoma, Arial, sans-serif"
    fontSize: "12px"
    fontWeight: 440
    lineHeight: "16px"
    letterSpacing: "-0.24px"
  button:
    fontFamily: "Inter, Tajawal, -apple-system, system-ui, 'Segoe UI', Roboto, Tahoma, Arial, sans-serif"
    fontSize: "14px"
    fontWeight: 460
    lineHeight: "21px"
    letterSpacing: "-0.28px"
rounded:
  md: "6px"
  lg: "8px"
  xl: "12px"
  2xl: "16px"
  full: "9999px"
spacing:
  1: "4px"
  2: "8px"
  3: "12px"
  4: "16px"
  6: "24px"
  8: "32px"
components:
  button-primary:
    backgroundColor: "{colors.brand-violet}"
    textColor: "{colors.card}"
    typography: "{typography.button}"
    rounded: "{rounded.lg}"
    padding: "0 12px"
    height: "32px"
  button-faded:
    backgroundColor: "{colors.violet-mist}"
    textColor: "{colors.violet-ink}"
    typography: "{typography.button}"
    rounded: "{rounded.lg}"
    padding: "0 12px"
    height: "32px"
  button-neutral:
    backgroundColor: "{colors.card}"
    textColor: "{colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.lg}"
    padding: "0 12px"
    height: "32px"
  button-danger:
    backgroundColor: "{colors.signal-ruby}"
    textColor: "{colors.card}"
    typography: "{typography.button}"
    rounded: "{rounded.lg}"
    padding: "0 12px"
    height: "32px"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.lg}"
    padding: "0 12px"
    height: "40px"
  card:
    backgroundColor: "{colors.card}"
    textColor: "{colors.ink}"
    rounded: "{rounded.xl}"
    padding: "24px"
  nav-item:
    textColor: "{colors.ink-muted}"
    typography: "{typography.body}"
    rounded: "{rounded.lg}"
    padding: "4px 8px"
    height: "32px"
  nav-item-active:
    backgroundColor: "{colors.violet-mist}"
    textColor: "{colors.violet-ink}"
    typography: "{typography.subtitle}"
    rounded: "{rounded.lg}"
    padding: "4px 8px"
    height: "32px"
  status-pill:
    backgroundColor: "{colors.violet-mist}"
    textColor: "{colors.violet-ink}"
    typography: "{typography.label}"
    rounded: "{rounded.full}"
    padding: "2px 8px"
---

# Design System: MyDesk

## Overview

**Creative North Star: "The Merchant's Control Room"**

MyDesk is the calm room a merchant runs their customer operation from. Everything that matters is in view and measured: conversations arriving from every channel, campaigns going out, orders changing state. The room is quiet so that what changes is impossible to miss. Neutral, flat surfaces carry the work; a single brand violet marks what you can act on and where you are; four signal colors report outcomes and nothing else.

The system is dense where people work and generous where they decide. Lists, tables and conversation cards are compact and scannable for the employee who lives in them all day; summaries, totals and page headers open up for the owner who reads them to decide. The interface is built Arabic-first and right-to-left, using logical properties so every layout mirrors without special cases.

Depth comes from tone and a single hairline outline, not from shadows. Nothing floats unless it is temporarily on top of the work (menus, dialogs, toasts).

**Key Characteristics:**
- Flat neutral surfaces with 1px outlines; shadows only on overlays.
- One brand violet for actions, selection and "you are here"; signal colors only for outcomes.
- Compact working density in lists and tables, open spacing for headers and summaries.
- Arabic-first, RTL by default, logical layout properties throughout.
- Light and dark themes from the same tokens (CSS variables), never hard-coded per theme.

## Colors

A quiet neutral room with one confident violet and four signal colors that only speak about outcomes. Every value is a CSS variable with a light and a dark version; the hex values here are the light theme.

### Primary
- **Brand Violet** (`brand-violet`): the action color. Primary buttons, the focus outline of inputs, the active tab underline, the brand mark. In code: `n-brand` and the `n-blue-9` step (the "blue" scale was re-tinted to the brand violet).
- **Violet Ink** (`violet-ink`): violet text on light surfaces: link-style and faded buttons, active navigation labels, selected states, numbers that are actionable. In code: `n-blue-11`.
- **Violet Mist** (`violet-mist`): the selected and "you are here" background: active sidebar item, open conversation card, active filter chip, faded buttons. In code: `n-blue-3` (or `n-brand/10`).

### Neutral
- **Ink** (`ink`): primary text, headings, values. `n-slate-12`.
- **Muted Ink** (`ink-muted`): secondary text, metadata, table body text, inactive navigation. `n-slate-11`.
- **Faint Ink** (`ink-faint`): placeholders and disabled marks only; never for text people must read. `n-slate-9`/`n-slate-10`.
- **Canvas** (`canvas`): the app background behind panels. `n-background`.
- **Surface** (`surface`) and **Card** (`card`): working panels and contained sections. `n-surface-1`, `n-card`/`n-solid-1`.
- **Weak Line** (`line-weak`) and **Strong Line** (`line-strong`): hairline outlines and dividers; strong for input hover and emphasized edges. `n-weak`, `n-strong`.

### Signal
- **Teal** (`signal-teal`, ink `signal-teal-ink`): success and completion: delivered, resolved, enabled, sent. Shown as a teal-3 pill with teal-11 text.
- **Ruby** (`signal-ruby`, ink `signal-ruby-ink`): failure and destructive actions: failed, refused, delete.
- **Amber** (`signal-amber`, ink `signal-amber-ink`): in progress and attention: sending, pending, partial, warnings.

### Chat
- **Employee Bubble** (`bubble-employee`): the background of messages sent by employees in a conversation (`n-solid-blue`). It is a light blue inherited from upstream and does not follow the brand violet yet; decide this explicitly before changing it.

### Named Rules
**The One Violet Rule.** The brand violet family (`n-brand`, `n-blue-*`) is the only violet. The Radix `n-violet-*` scale is not part of the MyDesk system; MyDesk screens never use it.

**The Signals Report Outcomes Rule.** Teal, ruby and amber appear only to report a result or state (sent, failed, pending). They never decorate, never color an icon for flavor, and never stand in for the brand.

**The Three-Step Pill Rule.** Every status pill is the signal's 3-step background with its 11-step text (e.g. `teal-3` / `teal-11`). Never full-strength 9-step fills behind small text.

## Typography

**Body Font:** Inter for Latin text and figures, with the system UI stack as fallback (`-apple-system, system-ui, Segoe UI, Roboto, Tahoma, Arial`).
**Arabic Font:** Tajawal (chosen by the product owner for clarity, 2026-10-27). Inter carries no Arabic glyphs, so the stack `Inter, Tajawal, …` gives every Arabic character to Tajawal and every Latin letter and digit to Inter within the same line. Tajawal is SIL Open Font License; it is self-hosted with the app, not loaded from a third-party CDN. *Status: decided, not yet implemented in code.*

**Character:** one quiet sans voice for everything (headings, labels, data). Latin hierarchy is tuned with Inter's fine intermediate weights (420, 440, 460, 520); Arabic uses Tajawal's static weights, so in Arabic the same roles land on 400 (body, labels), 500 (headings, buttons, emphasis) and 700 (headline numbers only). Tajawal has no 600 weight: never request it.

### Hierarchy
- **Headline** (520, 18px, 24px line): page titles and panel headers (`text-heading-1`).
- **Title** (500, 16px, 24px line): section headings, card titles, the contact name in a conversation (`text-heading-2`).
- **Subtitle** (500, 14px, 21px line): card headings, breadcrumbs, table headers, field labels (`text-heading-3`).
- **Body** (420, 14px, 21px line): general text, table cells, messages (`text-body-main`).
- **Label** (440, 12px, 16px line): metadata, timestamps, pills, helper text (`text-label-small`).
- **Button** (460, 14px; 440, 12px for small buttons) (`text-button`, `text-button-small`).

Numbers that are compared or scanned (counts, durations, IDs) use tabular figures (`tabular-nums`).

### Named Rules
**The Small Steps Rule.** Hierarchy moves in steps of 2px and 20–40 weight units. A screen needs no type larger than 18px except a deliberate headline number in a summary.

**The No Tracking on Arabic Rule.** The negative letter-spacing in the type utilities is tuned for Inter. Arabic is a connected script: Tajawal text carries no letter-spacing (`letter-spacing: normal` in Arabic contexts).

**The Tajawal Size Check Rule.** Tajawal's Arabic letters sit smaller than Inter's Latin at the same pixel size. Check 12px labels and 14px table cells in Arabic on real screens; if they read small, raise Arabic text by 1px through the type utilities, never per component.

## Layout

Three working columns on desktop for conversations (navigation sidebar, list, workspace) and a single scrolling column for settings, campaigns and reports. Page content sits in a centered container of 64rem (`max-w-5xl`) for forms and 72rem (`max-w-6xl`) for data pages, with 24px side padding.

Spacing follows a 4px base scale (4, 8, 12, 16, 24, 32). Related items sit 4–8px apart, controls in a group 8–12px, sections 24px, and page sections 24–32px. Cards pad 24px; table cells and list rows are compact (12–16px).

Breakpoints: 480, 640, 768, 1024, 1280, 1536 and 1900px. Below 768px the sidebar becomes a slide-in menu, tables scroll horizontally inside their card (never the page), and two-column forms collapse to one with the preview below.

**The Mirror Rule.** Layout uses logical properties only (`ms`/`me`, `ps`/`pe`, `start`/`end`, `text-start`); direction-specific `left`/`right` appear only where a value is physical by nature (for example a phone number or URL forced `dir="ltr"`).

## Elevation & Depth

Flat by default. Surfaces are separated by tone (canvas behind, surface and card in front) and a 1px inset outline (`outline-1 -outline-offset-1`, weak line color), not by shadows. Shadows are reserved for things that sit temporarily above the work: dropdown menus, popovers, dialogs and toasts.

**The Flat-At-Rest Rule.** A card, panel, table or list item never carries a shadow at rest. If something needs to stand out, give it a tonal background (violet mist for selection) or a stronger outline, not depth.

## Shapes

Gently rounded, never pill-shaped containers. Inputs, buttons and navigation items use 8px corners; cards, panels and grouped sections use 12px; illustrative marks and large empty-state icons use 16–24px. Fully round shapes are only for avatars, status dots, count badges and status pills.

## Components

### Buttons
Quiet until they matter: one solid violet button per view, everything else softer.
- **Shape:** gently rounded (8px). Sizes 24 / 32 / 40 / 48px high (xs / sm / md / lg); pages mostly use 32px.
- **Primary (solid):** brand violet fill, white text; hover brightens 10%; press scales to 97–98%.
- **Faded:** violet mist background with violet ink text; for secondary actions such as "Details" or "Connect".
- **Neutral (slate):** white button with a hairline outline and ink text; for Cancel, Refresh, Back.
- **Ghost:** no background until hover (alpha-2); for icon buttons in rows (edit, delete).
- **Danger:** ruby, used for delete and disconnect, usually faded or ghost in lists and solid only in the confirm dialog.
- **Loading:** a spinner replaces the icon and the button keeps its width.

### Status pills
The language of outcomes.
- **Style:** fully round, 2px × 8px padding, 12px medium text, the signal's 3-step background with 11-step text (Three-Step Pill Rule).
- **Uses:** campaign status, delivery result, conversation status, enabled/disabled.

### Cards / Containers
- **Corner Style:** 12px.
- **Background:** card white on the canvas.
- **Shadow Strategy:** none (Flat-At-Rest Rule).
- **Border:** 1px inset outline in the weak line color.
- **Internal Padding:** 24px; section title (Title) then 16px to content.

### Summary tiles
The control room's gauges.
- **Style:** a compact card (16px padding, 12px corners, hairline outline) with a 36px rounded-square icon well (alpha-2 background, icon in violet ink or the relevant signal ink), the value in 18px semibold tabular figures, and a 12px muted label.
- **Layout:** a responsive row of 2 / 3 / 4–6 tiles above the table or chart they summarize.

### Inputs / Fields
- **Style:** 40px high, 8px corners, faint fill (`alpha-black2`), 1px weak outline; the label sits above in Subtitle.
- **Focus:** the outline turns brand violet.
- **Error / Disabled:** ruby outline with a ruby helper line below; disabled at 50% opacity.

### Navigation
- **Sidebar:** 200px, items 32px high with 8px corners, 14px text in muted ink, 16px icons. Hover adds a faint tonal background.
- **Active item:** violet mist background, violet ink label, medium weight. The group containing the active page keeps a violet icon.
- **Tabs:** 14px medium labels with count chips; the active tab gets a violet underline and violet text.
- **Mobile:** the sidebar slides in from the start edge, opened by a floating menu button.

### Tables
- **Style:** full-width, no outer frame inside a card; rows divided by weak lines; header row in Subtitle ink; cells in Body muted ink with primary values in Ink.
- **Behavior:** wide tables scroll horizontally inside their container with a minimum width; IDs and numbers use tabular figures; the last column holds row actions aligned to the end.

### Conversation card
The employee's unit of work.
- **Structure:** 40px avatar, then the name and time on one line, then the last message with the unread badge at its end; channel name and labels as small metadata. Under the message, a status pill leads the labels row.
- **Status pill:** each status keeps one colour and one icon: open in violet (the work to act on), pending in amber, resolved in teal, snoozed in neutral slate.
- **States:** the open conversation has a violet mist background; unread conversations show a semibold name and violet time.

### Filter chips
- **Style:** fully round, 28px high (36px on touch), 14px text, hairline weak outline; the active chip is violet mist with violet ink. They wrap onto a second row rather than scroll, so every filter stays in view.
- **Uses:** the status and quick views of the conversation list (all, open, unread, unreplied, pending, snoozed, closed), one active at a time.

## Do's and Don'ts

### Do:
- **Do** use the brand violet family (`n-brand`, `n-blue-3/9/11`) for every action, selection and active state.
- **Do** report outcomes with signal pills: `teal-3/11` success, `amber-3/11` in progress, `ruby-3/11` failure.
- **Do** separate surfaces with a 1px inset outline (`outline-1 -outline-offset-1 outline-n-weak`) and 12px corners.
- **Do** use the existing type utilities (`text-heading-1/2/3`, `text-body-main`, `text-label-small`) instead of ad-hoc sizes, and `tabular-nums` for data.
- **Do** write layout with logical properties so RTL and LTR both work, and force `dir="ltr"` only on numbers, phone numbers, IDs and URLs.
- **Do** use the shared components (`Button`, `Input`, `BaseTable`, `Breadcrumb`, `TabBar`, `ComboBox`) rather than restyling raw elements.

### Don't:
- **Don't** use the Radix `n-violet-*` scale on MyDesk screens (One Violet Rule).
- **Don't** put shadows on cards, panels, tables or list rows; shadows belong to overlays only.
- **Don't** use signal colors for decoration, or full-strength signal fills behind small text.
- **Don't** add letter-spacing to Arabic text, or request a Tajawal weight it does not have (600).
- **Don't** use `left`/`right` physical properties for layout, or hard-code a color per theme instead of using the CSS-variable tokens.
- **Don't** place more than one solid violet button in the same view.
