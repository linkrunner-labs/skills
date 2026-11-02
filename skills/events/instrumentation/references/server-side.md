# Server-side event & revenue APIs

Source of truth: https://docs.linkrunner.io/api-reference/event-capture and
https://docs.linkrunner.io/api-reference/revenue-tracking

Use these HTTP APIs for server-to-server tracking (webhooks, cron jobs,
backend order processing) - and for revenue from a web app, since the
Linkrunner web SDK has no client payment call.

App payments go through **Capture Event** with the payment fields. **Capture
Payment** is deprecated for app payments (it keeps working) and is still the
path for website payments with `"source": "web"`.

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
| `event_name` | string | **Required.** Name of the event. For a payment, the payment type (stored exactly as sent) |
| `event_data` | object | Optional. Additional data, such as Meta/Google product fields. An `amount` in here does **not** make a payment |
| `user_id` | string | **Required** unless `install_instance_id` is sent. Always send it for payments |
| `install_instance_id` | string | **Required** unless `user_id` is sent |
| `event_id` | string | Optional. Your own id for the event |
| `amount` | number | Payment field. Order total, 0 or more |
| `payment_id` | string | Payment field. Your unique transaction id, non-empty |
| `currency` | string | Payment field. 3-letter ISO 4217 code |
| `status` | string | Optional, payments only. `PAYMENT_INITIATED`, `PAYMENT_COMPLETED` (default), `PAYMENT_FAILED`, `PAYMENT_CANCELLED` |

```bash
curl -X POST https://api.linkrunner.io/api/v1/capture-event \
  -H "Content-Type: application/json" \
  -H "linkrunner-key: YOUR-SERVER-KEY" \
  -d '{
    "event_name": "purchase_completed",
    "amount": 149.99,
    "payment_id": "ORD-12345",
    "currency": "USD",
    "event_data": { "content_ids": ["ABC123"], "order_id": "ORD-12345" },
    "user_id": "user_12345"
  }'
```

**Payment fields:** send `amount`, `payment_id` and `currency` at the top
level, all three together. With none of them, or only one or two, the
request is a custom event and still returns `200`. Old payment types keep their uppercase spelling as
`event_name` (`FIRST_PAYMENT`, `DEFAULT`, ...) so existing mappings keep
matching. A retry with the same `payment_id`, `event_name` and `status` is
not stored twice and still returns `200`. Refund: same `event_name` and
`payment_id` with `status` `PAYMENT_CANCELLED`.

Responses: `200` event or payment captured, `400` missing or invalid
parameters (including an invalid payment field when all three are sent), `401` invalid server key.

For the ecommerce (`AddToCart`/`ViewContent`) field requirements, see
`references/ecommerce-events.md`.

## Capture Payment (deprecated for app payments)

```
POST /capture-payment
```

Deprecated for app payments: it keeps working for existing integrations, but
send new app payments through Capture Event above. Website payments still use
it with `"source": "web"` (see
https://docs.linkrunner.io/api-reference/revenue-tracking#website-payments);
those are **not** deduplicated.

| Parameter | Type | Description |
| --- | --- | --- |
| `user_id` | string | **Required** |
| `payment_id` | string | Optional but recommended - dedup key together with `type` (app payments only) |
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

## Remove Payment (legacy)

```
POST /remove-payment
```

No longer in the API docs. For a refund, send Capture Event with the same
`event_name` and `payment_id` and `status` `PAYMENT_CANCELLED` instead.

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
