# SwanSport — Stitch Mobil Uygulama Geneli Yeniden Tasarım Master Promptu

Bu metin her Stitch üretiminde aynen korunmalı; yalnızca en alttaki
`CURRENT BATCH` bölümü değiştirilmelidir.

---

## STITCH PROMPT

You are redesigning the **existing SwanSport Flutter mobile application**.
This is a real sports club operations platform and social sports network, not
a fictional concept and not a new application. Preserve its existing product
architecture, routes, roles, permissions and workflows. Redesign the visual
hierarchy and interaction layer only. Produce implementation-ready mobile
screens that can be recreated with Flutter widgets and the existing SwanSport
design tokens.

Use the already approved **SwanSport Ana Akış** screen in this Stitch project
as the visual source of truth. Every new screen must clearly belong to the same
application.

### Product context

SwanSport serves athletes, parents, coaches, club administrators, accountants,
officials, store owners and platform administrators. A person may have more
than one role at the same time. Never add an “active role selector”. Show
role-specific content in the same experience with small contextual labels such
as “Antrenör olarak”, “Veli olarak” or “Yönetici olarak”. Permissions are
determined by the backend; do not imply that a hidden control grants or removes
access.

The app combines:

- social posts, club announcements, sports news, follows and messaging;
- athlete rosters, attendance, calendar, teams and club documents;
- club finance, fees, donations, expenses and accountant workflows;
- branch-specific training sessions, timers, sets, scores and performance;
- sports venues, partner search, clubs, coaches and organizations;
- a sports equipment marketplace for new and second-hand goods;
- verification, privacy, support, configuration and health eligibility.

### Non-negotiable application shell

- Mobile canvas: **390 × 844**, responsive from 360 to 620 logical pixels.
- Exactly five bottom navigation destinations, always in this order:
  **Ana Sayfa · Keşfet · central Create · Mesajlar · Profil**.
- Do not add a sixth destination, hamburger module launcher, floating module
  catalogue or role-dependent bottom navigation.
- The center Create action opens a bottom sheet. It is not a separate tab.
- Primary screens use the five-item bottom navigation. Detail, editor and
  focused task screens use a back button and do not duplicate the bottom bar.
- Top-right inbox actions are notification and message icons with optional
  badges. Do not duplicate Profile with a tappable header avatar.
- Preserve old deep-link destinations even when two features share a tabbed
  screen: Venues, Messages/Communities and Partner Search.

### Visual language

- Premium, calm, contemporary sports-product feel. Avoid generic enterprise
  dashboards, template-like Material cards and childish gamification.
- Light palette: background `#F4F7FA`, surface `#FFFFFF`, secondary surface
  `#F1F5F8`, divider `#EAEEF3`, primary ink `#111827`, muted ink `#636B77`,
  accent `#008C95`, warning `#D9860B`, danger `#F43F5E`, success `#10B981`.
- Dark palette: background `#0A111E`, surface `#131D2E`, secondary surface
  `#1A2537`, divider `#233149`, primary ink `#FFFFFF`, muted ink `#8A97AC`,
  accent `#2FBFB6`. Never use pure black.
- Teal accent is reserved for the primary action, selected state and active
  progress. Do not use teal as decorative borders around every card.
- Typography: **Sora** for display and headings; **Plus Jakarta Sans** for
  body, labels and controls. Use only this scale: 32, 28, 22, 18, 16, 14, 12.
- “SwanSport” may use a handwritten wordmark feeling only in brand positions;
  never use script typography for functional copy.
- Spacing tokens: 4, 8, 12, 16, 24. Default screen gutter: 16.
- Radius tokens: 10 for small badges/icon wells, 14 for controls and rows, 22
  only for media heroes and bottom sheets.
- Prefer whitespace, typography, section backgrounds and thin dividers over
  bordered cards. Use very few shadows. Never put every row inside a floating
  rounded rectangle.
- Use real Turkish interface copy with correct characters. Avoid lorem ipsum,
  English labels and all-caps section titles.
- Every tap target is at least 44 × 44. Maintain WCAG AA contrast and support
  text scaling without clipping.

### Shared component grammar

Build every screen from a consistent, reusable grammar:

- compact scrolling app bar;
- page title plus one short contextual subtitle when needed;
- section heading with an optional text action on the right;
- plain list rows separated by spacing or one subtle divider;
- status chips with semantic colors and short labels;
- segmented tabs only for 2–3 short choices;
- pill tabs for four or more choices and optional counts;
- one dominant filled button per viewport; secondary actions are text or
  neutral tonal controls;
- bottom sheets for creation choices, filters and compact forms;
- full pages for long forms, destructive decisions and multi-step tasks;
- skeleton loading that resembles the final layout;
- empty states that explain what is missing and offer one relevant action;
- recoverable error states with “Tekrar dene”;
- offline states that preserve already loaded content and clearly label queued
  writes;
- confirmation feedback that does not block the next task.

Never communicate state using color alone. Pair color with an icon and label.
Tables must become readable mobile lists, not horizontally squeezed desktop
tables. Charts must have a textual summary and accessible legend.

### Information hierarchy and behaviour

- Put the user’s next decision or task first, supporting context second and
  history last.
- Do not turn operational screens into menu catalogues. Show the work directly.
- Use progressive disclosure: summary first, details on tap.
- Keep search and filters close to the list they affect. Active filters must be
  visible and removable.
- Preserve unsaved form state when changing a local filter or opening a helper
  sheet.
- Destructive actions require clear confirmation and must be visually separated
  from primary actions.
- Financial totals distinguish confirmed, expected and uncertain amounts.
- Accountant views must never display athlete names; show stable anonymous
  references such as `#A3F91C`.
- Health eligibility shows only “Uygun”, “İzin bekliyor” or “Kısıtlı”. Never
  display diagnosis or medical notes to club staff.
- Minor accounts default to follower-only social visibility and do not promote
  external sharing.
- Marketplace “Sıfır” goods must visually identify a verified store. Individual
  sellers may create only second-hand listings. Do not invent checkout, escrow,
  shipment tracking or ratings; those features do not exist.

### Screen families to redesign

Create a coherent screen for every route and major state in these families.
Do not merge screens whose tasks have different save behaviour.

1. **Core social shell**
   - Ana Akış (already approved; use as reference, do not redesign from zero)
   - Keşfet, Arama, Bildirimler
   - Mesajlar + Topluluklar tabs, direct chat, community chat
   - Profile, club profile, connections, saved posts, privacy
   - content creation bottom sheet and post creation states

2. **Club daily operations**
   - command centre / coach dashboard
   - athlete workspace, athlete list, athlete detail and guardian-linked athlete
   - live attendance and attendance history as separate screens
   - schedule calendar, event detail and event roster
   - announcements list/detail/editor
   - team directory and team roster
   - document vault, document detail and upload/version states

3. **Finance and administration**
   - finance overview, finance task queue and personal fees
   - quick expense, expense detail, approval and rejection
   - donations/campaigns
   - confirmed/expected/uncertain cash projection
   - closed-period and reversal transaction states
   - accountant privacy variants using anonymous athlete references

4. **Training and performance**
   - My Training, protocol/template library
   - athlete-controlled live session
   - phase timer, rest timer, set progression, score entry and pause/resume
   - simple and detailed modes
   - archery example: waiting time, shooting time, configurable sets/arrows,
     score entry after arrow collection, next set and final result
   - session result and coach review
   - performance overview, athlete performance, tests, team performance,
     development plans, match/training/position analysis and editor states

5. **Discovery and marketplace**
   - club discovery and club detail
   - coach discovery
   - venues with Courts + Football Pitches tabs and venue detail
   - partner search with Partner + Player Wanted tabs
   - organizations and federation channel
   - marketplace home, search/filter, category results, listing detail
   - create second-hand listing, verified-store new product flow and store
     application/status

6. **Account, safety and support**
   - onboarding, authentication and role declaration
   - credential verification, guardian linking, pending approval and admin review
   - settings, appearance, club identity configuration and feature configuration
   - medical eligibility centre using privacy-safe statuses
   - Help/FAQ and support ticket conversation
   - permission denied, expired session and reconnect states

### Output requirements for every batch

- Generate separate full mobile screens, not one giant collage and not one
  endless dashboard.
- Name every screen with its exact Turkish product title.
- Show the normal populated state first. Add the most important empty, loading,
  error, permission and offline variants beside it when relevant.
- Annotate the intended interaction of tabs, buttons, sheets and row taps in a
  short screen description.
- Reuse patterns already established in earlier batches. Do not reinterpret
  the palette, typography, navigation or card style in later batches.
- Do not add capabilities, data or navigation that are absent from this brief.
- Optimize for Flutter implementation: standard rows, stacks, slivers, tabs,
  sheets and responsive constraints; avoid web-only effects and impossible
  overlapping geometry.

### Quality gate before returning a screen

Check all of the following:

1. Does it look like the approved SwanSport Ana Akış?
2. Is the next user action obvious within three seconds?
3. Is there more than one dominant filled action in the same viewport? If yes,
   simplify it.
4. Can a 360 px phone display it without overflow?
5. Does the dark version avoid pure black and preserve contrast?
6. Did you accidentally add a role switcher, module launcher or sixth bottom
   tab? Remove it.
7. Did you hide essential information inside a decorative card grid? Convert it
   into sections or rows.
8. Does every sensitive finance/health state respect the privacy constraints?
9. Are all labels natural Turkish?
10. Can the screen be implemented with the existing Flutter design tokens?

### CURRENT BATCH

Design **Batch 1 — Core social shell** now. Generate these as separate,
consistent mobile screens in this order:

1. Keşfet
2. Arama and search results
3. Bildirimler
4. Mesajlar with Direct Messages + Topluluklar tabs
5. Direct chat
6. Profile
7. Club profile
8. Connections
9. Saved posts
10. Create-content bottom sheet

Use realistic Turkish sports-club data. Show the normal populated state for
all ten. Also show: empty search, no notifications, empty inbox and blocked
profile as compact state variants. Keep the approved Ana Akış unchanged and
use it as the style reference.

---

## Sonraki batch değişimleri

Master promptun tamamı korunur. Yalnızca `CURRENT BATCH` bölümü sırasıyla şu
başlıklarla değiştirilir:

1. Core social shell
2. Club daily operations
3. Finance and administration
4. Training and performance
5. Discovery and marketplace
6. Account, safety and support

