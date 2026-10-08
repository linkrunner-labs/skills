---
name: linkrunner-events
description: >-
  Instrument Linkrunner event and revenue tracking correctly - what events to
  send, when to send them, and how to avoid double-counted, dropped, or
  missing revenue. Platform-agnostic: covers the event taxonomy, event
  parameters, ad-network ecommerce fields, capturePayment/removePayment
  correctness, and the server-side Capture Event / Revenue Tracking HTTP APIs.
  Use when asked to instrument Linkrunner events, track purchases or revenue
  with Linkrunner, decide what events or event parameters to send, debug why
  revenue or events are missing or double-counted, or send events and
  payments from a backend.
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
`trackEvent` / `capturePayment` / `removePayment` snippets for that language.

## 0. Before you touch anything

1. Confirm **`signup()` has already been wired** for this app so events and
   payments are linked to a user. Events and revenue are stored for every
   user, attributed or organic; ones from users with no matching click are
   stored without campaign attribution. If `signup` isn't wired yet, set it up
   first via the relevant `skills/sdk/<platform>/` skill.
2. Identify which SDK is installed (Flutter, React Native, Expo, iOS,
   Android, Capacitor, Cordova, Unity, Web) - or whether this is a
   backend flow with **no client SDK in the loop**. That decides whether
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
| "What events should I send" / "instrument Linkrunner events" / "which event parameters" | `references/ecommerce-events.md` for the taxonomy and event parameters, then the platform skill's `events.md` for exact call syntax |
| "Track purchases / revenue" / "revenue is wrong, missing, or double-counted" | `references/revenue.md` |
| "Track events from my backend / server" | `references/server-side.md` |
| "Track events from my website" (web SDK) | `lr.track(eventName, data)`, see https://docs.linkrunner.io/sdk/web. Send payments you need to trust from your backend (`references/server-side.md`) |
| "AddToCart / ViewContent / Purchase not showing in Meta" | `references/ecommerce-events.md`, then confirm the custom event is **mapped** to the standard commerce event in the dashboard (Meta Ads → Event Mapping) |

## 2. Golden rules

- Events and payments are stored for every user, attributed or organic
  (organic ones carry no campaign). Run `signup()` (or `.signup`) first so
  they are linked to a user.
- **Send one event with parameters, not one event per variant.** Send
  `purchase` with `{ plan: "gold" }`, not `purchase_gold` and
  `purchase_silver`. One event name keeps funnels, campaign columns and
  postback mappings simple, and the dashboard can filter and break down by
  `plan`. Keep parameters flat, use the same keys and value types every time,
  and never put PII in them. See `references/ecommerce-events.md`.
- Client-side custom events and payments always go through the per-platform
  SDK - defer syntax to `skills/sdk/<platform>/references/events.md`. Don't
  invent a generic snippet here.
- For revenue, use `capturePayment` / the Capture Payment API, **not**
  `trackEvent` / Capture Event - the docs explicitly recommend
  capture-payment for revenue since it has dedup guarantees capture-event
  doesn't.
- Always send `amount` as a **number**, never a string, when you want
  ad-network revenue sharing (Meta/Google) to work.
- Meta Catalog Sales ecommerce events (`AddToCart`, `ViewContent`, `Purchase`)
  need specific `event_data` fields (`content_ids`, `contents`,
  `content_type`, `value`, `currency`, `num_items`, `order_id`) and the custom
  event name must be **mapped** to the standard commerce event in the
  Linkrunner dashboard before it will sync - sending the event alone isn't
  enough. See `references/ecommerce-events.md`.
- Payment dedup key is the `(type, payment_id)` combination - always send a
  unique `payment_id` per transaction so re-sends dedupe instead of silently
  colliding. See `references/revenue.md` for the full failure mode.
- The web SDK tracks custom events with `lr.track(eventName, data)` (see
  https://docs.linkrunner.io/sdk/web). It has no `capturePayment`; send
  payments and other events you need to trust from your backend with the
  server-side APIs in `references/server-side.md`.

## 3. Verify

- Check the dashboard [Events Settings](https://dashboard.linkrunner.io/dashboard/settings/events)
  page to confirm events are being captured.
- To test with an attributed user, so events carry a campaign, follow the
  [Integration Testing](https://docs.linkrunner.io/testing/integration-testing)
  guide.
- For Meta ecommerce events, check Meta Events Manager / Commerce Manager -
  allow up to 15 minutes for real-time hits and up to an hour for full event
  visibility.

## References

- `references/ecommerce-events.md` - event taxonomy, event parameters, Meta Catalog Sales fields, when to fire each event
- `references/revenue.md` - capturePayment/removePayment correctness, dedup, refunds, double-counting
- `references/server-side.md` - Capture Event / Revenue Tracking HTTP APIs for server-to-server tracking, including payments from a website
