# Revenue tracking correctness

Source of truth: https://docs.linkrunner.io/api-reference/revenue-tracking

Revenue goes through `capturePayment` client-side, or the Capture Payment API
server-side (`references/server-side.md`) - **not** `trackEvent`/Capture
Event. The docs explicitly recommend capture-payment over capture-event for
revenue, since it carries dedup guarantees capture-event doesn't. For the
exact client call in your language, see
`skills/sdk/<platform>/references/events.md`.

```
capturePayment({ userId, amount, paymentId, type, status, eventData })  // client
removePayment({ userId, paymentId })                                    // client
POST /capture-payment  /  POST /remove-payment                          // server-side
```

## Fields

- `user_id` - **required**. Must match a user already registered via
  `signup()`; revenue is only stored and displayed for attributed users.
- `amount` - **required**, one currency only. If you accept payments in
  multiple currencies, convert to a single currency before calling.
- `payment_id` - optional but recommended, unique per transaction. See dedup below.
- `type` - optional, defaults to `DEFAULT`. One of: `FIRST_PAYMENT`,
  `SECOND_PAYMENT`, `WALLET_TOPUP`, `FUNDS_WITHDRAWAL`,
  `SUBSCRIPTION_CREATED`, `SUBSCRIPTION_RENEWED`, `ONE_TIME`, `RECURRING`,
  `DEFAULT`.
- `status` - optional, defaults to `PAYMENT_COMPLETED`. One of:
  `PAYMENT_INITIATED`, `PAYMENT_COMPLETED`, `PAYMENT_FAILED`,
  `PAYMENT_CANCELLED`.
- `event_data` - optional. Use for the Meta ecommerce `Purchase` fields (see
  `references/ecommerce-events.md`) or any other custom attributes.

## Deduplication

Deduplication is idempotent on the **`(type, payment_id)` combination**. For
each unique combination, only one record is created - a second call with the
same `type` + `payment_id` is silently ignored. This is what makes retries
safe.

**The failure mode runs both ways:**

- Reusing the same `payment_id` (or a constant/empty one) across genuinely
  different transactions of the same `type` causes every payment after the
  first to be dropped, not recorded twice - this reads as "missing revenue,"
  not double-counting. Always generate a fresh, unique `payment_id` per real
  transaction.
- Calling `capturePayment` both from the client SDK and from your backend for
  the same transaction, with two different `payment_id` values (or one side
  omitting it), produces two separate records for one payment - this is the
  actual double-counting case. Pick one call site per transaction, or make
  sure both sides pass the identical `payment_id`.

## Refunds / removing payments

`removePayment` needs either `payment_id` or `user_id`.

**Passing only `user_id` removes all payments attributed to that user, not
just one.** To remove a single transaction, always pass its `payment_id`.

## Meta ecommerce `Purchase` events

To sync payments to Meta Catalog Sales, map the payment `type` you use (e.g.
`DEFAULT` or `FIRST_PAYMENT`) to `Purchase` in the Linkrunner dashboard (Meta
Ads → Event Mapping), and include the ecommerce fields in `event_data`:
`content_ids`/`item_group_ids`, `contents`, `content_type`, `currency`,
`value`, `num_items`, and `order_id` (required for `Purchase`). Field
definitions and examples: `references/ecommerce-events.md`.

Note: `MobileAppInstall` and `CompleteRegistration` are sent to Meta
automatically - no mapping or `capturePayment` call needed for those.

## Verify

- Dashboard → [Events Settings](https://dashboard.linkrunner.io/dashboard/settings/events) to confirm the payment is captured.
- If revenue isn't showing in Meta/Google: confirm "Send Revenue" is enabled on the event mapping, the currency is correct, and the app is actually sending a numeric `amount`/`value`.
