# Server-side event & revenue APIs

Source of truth: https://docs.linkrunner.io/api-reference/event-capture and
https://docs.linkrunner.io/api-reference/revenue-tracking

Use these HTTP APIs for server-to-server tracking (webhooks, cron jobs,
backend order processing). A website can track custom events in the browser
with the web SDK's `lr.track(eventName, data)` (https://docs.linkrunner.io/sdk/web),
but payments and other events you need to trust should come from your backend
through these APIs.

## Base URL & auth

```
https://api.linkrunner.io/api/v1
```

Generate a server key from the dashboard: https://dashboard.linkrunner.io/settings?s=data-apis

Every request needs this header:

```
linkrunner-key: YOUR-SERVER-KEY
```

Events and payments are stored for every user, attributed or organic.
Ones from users with no matching click are stored without campaign
attribution. Each request must identify the user with `user_id` (the same id
your app passed to `signup`) or `install_instance_id`.

## Capture Event

```
POST /capture-event
```

| Parameter | Type | Description |
| --- | --- | --- |
| `event_name` | string | **Required.** Name of the event |
| `event_data` | object | Optional. Event parameters - include a numeric `amount` to enable ad-network revenue sharing |
| `user_id` | string | **Required** unless `install_instance_id` is sent. User identifier to associate the event with |
| `install_instance_id` | string | **Required** unless `user_id` is sent. Linkrunner's ID for the install |
| `event_id` | string | Optional. Your own unique id for the event, for deduplication and correlating with your backend |

```bash
curl -X POST https://api.linkrunner.io/api/v1/capture-event \
  -H "Content-Type: application/json" \
  -H "linkrunner-key: YOUR-SERVER-KEY" \
  -d '{
    "event_name": "purchase_completed",
    "event_data": { "order_id": "ORD-12345", "amount": 149.99, "currency": "USD" },
    "user_id": "user_12345"
  }'
```

Responses: `200` captured, `400` missing required parameters (or neither
`user_id` nor `install_instance_id`), `401` invalid server key.

Send variants as event parameters on one event name (`purchase` with
`{ "plan": "gold" }`, not `purchase_gold`). See the event parameters section
in `references/ecommerce-events.md`.

For the ecommerce (`AddToCart`/`ViewContent`) field requirements, see
`references/ecommerce-events.md`.

## Capture Payment

```
POST /capture-payment
```

| Parameter | Type | Description |
| --- | --- | --- |
| `user_id` | string | **Required** |
| `payment_id` | string | Optional but recommended - dedup key together with `type` |
| `amount` | number | **Required**, single currency only |
| `type` | string | Optional, defaults to `DEFAULT` |
| `status` | string | Optional, defaults to `PAYMENT_COMPLETED` |
| `event_data` | object | Optional - Meta ecommerce `Purchase` fields or your own event parameters |

```bash
curl -X POST https://api.linkrunner.io/api/v1/capture-payment \
  -H "Content-Type: application/json" \
  -H "linkrunner-key: YOUR-SERVER-KEY" \
  -d '{
    "user_id": "666",
    "payment_id": "ABC",
    "amount": 25096,
    "type": "FIRST_PAYMENT",
    "status": "PAYMENT_COMPLETED"
  }'
```

Responses: `201` payment captured, `401` invalid server key.

Full field semantics (types, statuses, dedup, refunds) are in
`references/revenue.md` - don't duplicate that reasoning here, just the wire
format.

## Remove Payment

```
POST /remove-payment
```

| Parameter | Type | Description |
| --- | --- | --- |
| `user_id` | string | Either this or `payment_id` is required |
| `payment_id` | string | Either this or `user_id` is required |

```bash
curl -X POST https://api.linkrunner.io/api/v1/remove-payment \
  -H "Content-Type: application/json" \
  -H "linkrunner-key: YOUR-SERVER-KEY" \
  -d '{ "user_id": "666", "payment_id": "ABC" }'
```

Passing only `user_id` removes **all** payments for that user - see the
refunds section in `references/revenue.md` before wiring this into a refund
flow.

Responses: `200` deleted, `400` no payment found for the given id, `401`
invalid server key.

## Error handling

| Status | Meaning |
| --- | --- |
| `400` | Check request parameters |
| `401` | Verify the server key |
| `429` | Rate limited - back off and retry |
| `500` | Contact support@linkrunner.io if it persists |
