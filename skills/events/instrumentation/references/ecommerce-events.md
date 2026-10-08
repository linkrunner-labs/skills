# Event taxonomy & Meta Catalog Sales fields

Source of truth: https://docs.linkrunner.io/api-reference/event-capture and
https://docs.linkrunner.io/ecommerce-manager/meta-commerce-manager

Custom events go through `trackEvent` client-side, or the Capture Event API
server-side (`references/server-side.md`). This page covers **what** to send;
for the exact client call in your language, see
`skills/sdk/<platform>/references/events.md`.

```
trackEvent(event_name, event_data)   // client, name varies by platform
POST /capture-event                  // server-side, see references/server-side.md
```

## Generic event names

The docs list these as common event names - use them as a starting point, not
an enforced enum. Snake_case is the recommended convention.

| Event name | Description |
| --- | --- |
| `purchase_initiated` | User starts a purchase |
| `purchase_completed` | User completes a purchase |
| `item_viewed` | User views an item/product |
| `cart_added` | User adds item to cart |
| `checkout_started` | User starts checkout |
| `search_performed` | User performs a search |
| `content_viewed` | User views content |
| `level_completed` | User completes a level (games) |
| `achievement_unlocked` | User unlocks an achievement |
| `user_referred` | User refers someone |

For any of these, including a numeric `amount` in `event_data` enables
revenue-sharing with Meta/Google so they can optimize on conversion value -
`amount` must be a number, not a string. For actual payments, prefer
`capturePayment` (`references/revenue.md`) over `trackEvent`.

## Event parameters

Event parameters are the key-value pairs you already send as `eventData`
(SDKs) / `event_data` (wire) with `trackEvent` and `capturePayment`. The
dashboard can filter and break down events by them (events log, funnels,
users, campaign tables). Nothing new is collected; it uses what you send.

**Send one event with parameters, not one event per variant.** Send
`purchase` with `{ plan: "gold" }`, not `purchase_gold` and
`purchase_silver`. One event name keeps funnels, campaign columns and
postback mappings simple, and the dashboard can filter and break down by
`plan`.

```
trackEvent("purchase", { plan: "gold" })       // do this
trackEvent("purchase_gold")                    // not this
```

- **Keep keys top-level and values flat.** Filters and breakdowns work on
  top-level keys only. Values can be strings, numbers, booleans, or nested
  objects/lists, but nested values are only usable as text.
- **Keep values short.** Values over 256 characters are not used for filtering.
- **Same keys, same types, every time.** Don't send `plan: "gold"` sometimes
  and `plan_name: "Gold"` other times, or a number in one call and a string in
  the next.
- **No PII.** No emails, phone numbers or names; `signup`/`setUserData` have
  fields for those.
- Meta commerce fields (`content_ids`, `contents`, below) keep the shape Meta
  needs. These rules are for your own keys.

Docs: https://docs.linkrunner.io/features/event-parameters

## Meta Catalog Sales taxonomy

If the goal is feeding Meta Catalog Sales / Commerce Manager (retargeting on
`ViewContent`/`AddToCart`, dynamic product ads), there are exactly **3**
essential events:

- `Purchase` - via `capturePayment` / the Capture Payment API (`references/revenue.md`)
- `AddToCart` - via `trackEvent` / the Capture Event API
- `ViewContent` - via `trackEvent` / the Capture Event API

**Before sending, map the custom event to its standard commerce event in the
Linkrunner Dashboard** (Meta Ads → Event Mapping). For example, map
`add_to_cart` → `AddToCart`, `item_viewed` or `view_content` → `ViewContent`,
and the payment type you use (e.g. `DEFAULT` or `FIRST_PAYMENT`) → `Purchase`.
Sending the event without this mapping does not sync it to Meta.

### Required `event_data` fields

| Field | Type | Required for | Notes |
| --- | --- | --- | --- |
| `content_ids` | array | `Purchase`, `AddToCart`, `ViewContent` | Individual product/variant IDs, must exactly match the Content ID in the Meta catalogue |
| `item_group_ids` | array | alternative to `content_ids` | Use to boost an entire product group instead of one variant |
| `contents` | array of objects | `Purchase`, `AddToCart`, `ViewContent` | Each entry: `id` (matches `content_ids`/`item_group_ids`), `quantity`, `item_price` (must match the Meta catalogue price) |
| `content_type` | string | `Purchase`, `AddToCart`, `ViewContent` | `"product"` when using `content_ids`, `"product_group"` when using `item_group_ids` |
| `value` | number | `Purchase`, `AddToCart` | Total numeric value, e.g. sum of `item_price * quantity` |
| `currency` | string | required when `value` is sent | ISO 4217 code, e.g. `"USD"`, `"INR"` |
| `num_items` | number | `Purchase`, `AddToCart` | Total quantity across `contents` |
| `order_id` | string | `Purchase` | Backend-generated unique purchase order ID |

Example `AddToCart` payload (`content_ids` variant form):

```json
{
  "content_ids": ["sku_blue_tshirt_m"],
  "contents": [
    { "id": "sku_blue_tshirt_m", "quantity": 1, "item_price": 799 }
  ],
  "content_type": "product",
  "currency": "INR",
  "value": 799.0,
  "num_items": 1
}
```

Use `item_group_ids` + `content_type: "product_group"` instead when the user
interacted with a product group rather than one specific variant (e.g. viewed
"Blue T-Shirt" without picking a size).

Meta's **catalogue match rate** (target 90%+) depends on `content_ids` /
`item_group_ids` exactly matching catalogue IDs, and `item_price` matching the
catalogue price - mismatches quietly hurt ad delivery even if the event call
itself succeeds.

## Verify

- Dashboard → [Events Settings](https://dashboard.linkrunner.io/dashboard/settings/events) to confirm the event is captured.
- Meta Events Manager → Commerce Manager → Events, within ~15 minutes for the real-time hit (full data can take a few days to populate everywhere).
