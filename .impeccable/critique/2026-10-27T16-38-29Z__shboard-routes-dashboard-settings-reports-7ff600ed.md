---
target: reports pages
total_score: 21
max_score: 40
na_heuristics: 
p0_count: 2
p1_count: 2
target_identity: "file:\\\\wsl.localhost\\ubuntu\\home\\fahmiahmed\\chatwoot\\app\\javascript\\dashboard\\routes\\dashboard\\settings\\reports"
timestamp: 2026-10-27T16-38-29Z
slug: shboard-routes-dashboard-settings-reports-7ff600ed
---
# Critique: MyDesk reports pages

Target: app/javascript/dashboard/routes/dashboard/settings/reports/ (overview, conversation, agents/inboxes/labels/teams overviews, CSAT, SLA, bot)
Method: dual-agent (A: design review · B: detector + browser)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Live pills and date chip clear; CSAT/SLA/Bot show "0%" for no data, read as measured results |
| 2 | Match System / Real World | 1 | English durations/dates in Arabic UI; bidi scrambles "1 Min 33 Sec" into "Min 33 Sec 1" |
| 3 | User Control and Freedom | 3 | Date range, business hours, back link, filters behave as expected |
| 4 | Consistency and Standards | 1 | Two names per metric; تحميل/تنزيل, تصفية/فلتر, التسميات/الوسوم; typo «رضاء» |
| 5 | Error Prevention | 2 | SLA reachable and looks working with Enterprise off; fractional ticks on count charts |
| 6 | Recognition Rather Than Recall | 2 | Overview tables have no reference value (target / account average) |
| 7 | Flexibility and Efficiency | 2 | CSV + drilldown exist; no header sort, saved views, or on-screen previous-period comparison |
| 8 | Aesthetic and Minimalist Design | 3 | Calm and flat; four detail pages repeat 6 charts; empty heatmap is 168 empty cells |
| 9 | Error Recovery | 2 | Fetch-failed state exists; teams overview with no teams shows headers only |
| 10 | Help and Documentation | 2 | Descriptions and some ⓘ tooltips; no definitions of first response, average, business hours |
| **Total** | | **21/40** | **Acceptable** |

## Design Specificity Verdict

LLM: stock Chatwoot with Arabic translation and violet recolor; no channel view, no commerce/Salla link, inbox rows are raw names without channel icons; the Saudi-native promise fails on English durations/dates.

Detector: CLI exit 0, 0 primary findings, 3 advisories (ReportDrilldownCard.vue:253 text-[11px] real; two spec-file colors false positives). CLI text-matches .vue only. In-browser detect.js: 49 undersized-ui-text (10px heatmap hours, BaseHeatmap.vue:135 text-xxxs), low-contrast live badge #008573 on #e0f8f3 4.1:1 and empty-state slate-10 3.8:1, flat-type-hierarchy (max step 1.14), skipped headings h3→h5; 24 physical left/right classes on overview; <html> lacks lang/dir; live card overflows at ~518px. No Radix violet on report pages.

## Priority Issues

1. [P0] English durations/dates scrambled by bidi + terminology drift. Fix: Arabic duration/date formatting via Intl, <bdi>, tabular-nums, one glossary in ar/report.json and sidebar. Commands: typeset, clarify.
2. [P0] SLA report presented as working while Enterprise is disabled (Sidebar.vue:709 ungated; «معدل الالتزام 0%»). Fix: hide SLA route + item; replace later with MyDesk service level; bot empty state explaining no bot connected. Commands: distill, shape.
3. [P1] No empty/low-data states; zeros read as results; fractional ticks; inconsistent "--" vs "0%". Fix: "—" + «لا توجد بيانات كافية» at n=0, integer ticks, empty rows with next action. Commands: harden, onboard.
4. [P1] Heatmap legibility and accessibility, RTL: 10–11px clipped labels, 336 tab stops, generic switch name, physical properties, overflow at ~518px. Fix: 12px labels every 3h, roving tabindex, «ساعات العمل» label, logical properties, lang/dir on html. Commands: audit, adapt.
5. [P2] IA/KPIs don't serve the owner: four duplicate overview pages, 7 equal charts, averages only, previous-period delta not prominent, no channel view, solid download button outweighs data. Fix: one performance page with 4 KPI tiles + deltas, segmented employee/channel/label/team, channel icons, secondary download. Commands: shape, layout, distill.

## Persona Red Flags

- Alex: no header sort, no previous-period on screen, no account-average comparison, business-hours toggle unexplained, averages only.
- Sam: 336 heatmap tab stops, generic switch name, mixed-language SR labels, trend by color + triangle only, 11px text.
- Saudi small-store owner on phone: heatmaps scroll and labels collide, headers wrap word-per-line, English durations, no "who is waiting now, on which channel".

## Minor Observations

- KPI numbers 30px weight 400 without tabular figures; table numbers start-aligned.
- «تقارير CSAT» mixed script; heatmap SR text "7 rows across 24 columns." in English; redundant "Oct 21, 2026" under day names.
- Current font Inter + system fallback; Arabic headings heavy at 14px (Tajawal decided, not implemented).
- «بدون حضور», «فتح» literal translations.

## Questions to Consider

1. If the owner gets one number per day, which is it, and should reports be reduced until it leads?
2. Should a multi-channel product report by channel instead of inbox name, replacing three of the four overview pages?
3. Should reports tie conversations to Salla order outcomes?
