# Server-side event & revenue APIs

Source of truth: https://docs.linkrunner.io/api-reference/event-capture and
https://docs.linkrunner.io/api-reference/revenue-tracking

Use these HTTP APIs for server-to-server tracking (webhooks, cron jobs,
backend order processing) - and as the **only** way to track custom events or
revenue from a web app, since the Linkrunner web SDK doesn't expose a client
`trackEvent`/`capturePayment` call (it only auto-tracks page views and
exposes `getStoreLink`).

## Base URL & auth

```
https://api.linkrunner.io/api/v1
```

Generate a server key from the dashboard: https://dashboard.linkrunner.io/settings?s=data-apis

Every request needs this header:

```
linkrunner-key: YOUR-SERVER-KEY
```

Users must already be attributed via `.signup` in one of the client SDKs for
their events/payments to be stored and displayed.

## Capture Event

```
POST /capture-event
```

| Parameter | Type | Description |
| --- | --- | --- |
| `event_name` | string | **Required.** Name of the event |
| `event_data` | object | Optional. Additional data - include a numeric `amount` to enable ad-network revenue sharing |
| `user_id` | string | **Required.** User identifier to associate the event with |

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

Responses: `201` captured, `400` missing required parameters, `401` invalid
server key.

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
| `event_data` | object | Optional - Meta ecommerce `Purchase` fields |

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
