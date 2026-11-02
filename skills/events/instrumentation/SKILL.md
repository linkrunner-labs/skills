---
name: linkrunner-events
description: >-
  Instrument Linkrunner event and revenue tracking correctly - what events to
  send, when to send them, and how to avoid double-counted, dropped, or
  missing revenue. Platform-agnostic: covers the event taxonomy, ad-network
  ecommerce fields, payments sent with trackEvent (amount, paymentId,
  currency) and their dedupe and refunds, the deprecated
  capturePayment/removePayment, and the server-side Capture Event / Revenue
  Tracking HTTP APIs. Use when asked to
  instrument Linkrunner events, track purchases or revenue with Linkrunner,
  decide what events to send, debug why revenue or events are missing or
  double-counted, or send events from a backend/web app that has no client
  SDK call for custom events.
metadata:
  category: events
  slug: events
  docs: https://docs.linkrunner.io/api-reference/event-capture
---

# Linkrunner - Events & revenue instrumentation

You are instrumenting **Linkrunner** event and revenue tracking. This skill is
the platform-agnostic layer: what to send, when to send it, and how to keep
revenue correct. It does **not** give you client call syntax - each platform's
SDK skill (`skills/sdk/<platform>/references/events.md`) owns the exact
`trackEvent` snippets (custom events and payments) for that language.

## 0. Before you touch anything

1. Confirm **`signup()` has already been wired** for this app. Events and
   revenue are only stored and displayed for attributed users - a user must
   have been registered via `.signup` in an SDK before their events show up.
   If it isn't wired yet, stop and set that up first via the relevant
   `skills/sdk/<platform>/` skill.
2. Identify which SDK is installed (Flutter, React Native, Expo, iOS,
   Android, Capacitor, Cordova, Unity, Web) - or whether this is a
   backend/web flow with **no client SDK in the loop**. That decides whether
   you write client code or call the HTTP API.
3. Ask what's actually being tracked: generic product/behavior events,
   ecommerce events meant to feed Meta Catalog Sales, revenue/payments, or
   server-side-only tracking (cron jobs, webhooks, web backend).
4. If this is server-side work, get the **server key** (dashboard → Settings
   → Data APIs: https://dashboard.linkrunner.io/settings?s=data-apis). Never
   hardcode it - ask where the user keeps secrets.

## 1. Decide what the user actually needs

| They want... | Do this |
| --- | --- |
| "What events should I send" / "instrument Linkrunner events" | `references/ecommerce-events.md` for the taxonomy, then the platform skill's `events.md` for exact call syntax |
| "Track purchases / revenue" / "revenue is wrong, missing, or double-counted" | `references/revenue.md` |
| "Track events from my backend / web app / server" | `references/server-side.md` (also the only path for the web SDK, which has no client `trackEvent`) |
| "AddToCart / ViewContent / Purchase not showing in Meta" | `references/ecommerce-events.md`, then confirm the custom event is **mapped** to the standard commerce event in the dashboard (Meta Ads → Event Mapping) |

## 2. Golden rules

- Nothing shows up for an unattributed user. `signup()` (or `.signup`) must
  run before any event or payment call means anything.
- Client-side custom events and payments always go through the per-platform
  SDK - defer syntax to `skills/sdk/<platform>/references/events.md`. Don't
  invent a generic snippet here.
- A payment is `trackEvent` with `amount`, `paymentId` and `currency`
  together in `eventData`, plus `userId` (server: `POST /capture-event` with
  top-level `amount`, `payment_id`, `currency`). Needs the new SDK majors
  (Android/iOS/Flutter 5.0.0, rn-linkrunner/expo-linkrunner 4.0.0,
  capacitor-linkrunner 3.0.0, cordova-linkrunner 2.0.0). `amount` or
  `currency` without `paymentId` is just a custom event, not revenue.
- `capturePayment` / `removePayment` / `POST /capture-payment` are deprecated
  on those versions (still work, removed in a future major). Don't add new
  calls; to move existing ones use the migrate-payments skill
  (`npx @linkrunner/skills add migrate-payments`). On older SDK versions
  `capturePayment` is still the only payment API.
- The event name is the payment type, stored exactly as sent. Old types keep
  their uppercase spelling (`FIRST_PAYMENT`, `DEFAULT`, ...) so Meta, Google
  and SKAN mappings keep matching; `first_payment` is a new, unmapped type.
- Always send `amount` as a **number** (0 or more, the order total) and a real
  3-letter `currency` - ask the user, never guess it.
- Meta Catalog Sales ecommerce events (`AddToCart`, `ViewContent`, `Purchase`)
  need specific `event_data` fields (`content_ids`, `contents`,
  `content_type`, `value`, `currency`, `num_items`, `order_id`; for
  `Purchase` the value and currency come from the payment `amount` and
  `currency`) and the custom
  event name must be **mapped** to the standard commerce event in the
  Linkrunner dashboard before it will sync - sending the event alone isn't
  enough. See `references/ecommerce-events.md`.
- Payments dedupe on event name + `paymentId` + `status` - always send a
  unique `paymentId` per transaction so re-sends dedupe instead of silently
  colliding. The same `paymentId` under two event names counts twice. Refund
  = same name and `paymentId` with `status` `PAYMENT_CANCELLED`. See
  `references/revenue.md` for the full failure mode.
- Website payments (users of your website, not your app) still go to
  `POST /capture-payment` with `"source": "web"`; the capture-event payment
  fields apply to app users only. Custom event tracking from a web app goes
  through the server-side APIs in `references/server-side.md`.

## 3. Verify

- Check the dashboard [Events Settings](https://dashboard.linkrunner.io/dashboard/settings/events)
  page to confirm events are being captured.
- To attribute a test user before events will show up, follow the
  [Integration Testing](https://docs.linkrunner.io/testing/integration-testing)
  guide.
- For Meta ecommerce events, check Meta Events Manager / Commerce Manager -
  allow up to 15 minutes for real-time hits and up to an hour for full event
  visibility.

## References

- `references/ecommerce-events.md` - event taxonomy, Meta Catalog Sales fields, when to fire each event
- `references/revenue.md` - trackEvent payments, deprecated capturePayment/removePayment, dedup, refunds, double-counting
- `references/server-side.md` - Capture Event / Revenue Tracking HTTP APIs for server-to-server and web tracking
