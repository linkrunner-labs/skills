# Revenue tracking correctness

Source of truth: https://docs.linkrunner.io/sdk/track-payments and
https://docs.linkrunner.io/api-reference/event-capture#payment-fields

A payment is an in-app event with revenue. Client-side, send it with
`trackEvent` and put `amount`, `paymentId` and `currency` together in
`eventData`, plus `userId`. Server-side, send `POST /capture-event` with
`amount`, `payment_id` and `currency` at the top level
(`references/server-side.md`). For the exact client call in your language, see
`skills/sdk/<platform>/references/events.md`.

```
trackEvent(eventName, { amount, paymentId, currency, userId, status?, ...productFields })  // client
POST /capture-event  { event_name, amount, payment_id, currency, user_id, status?, event_data? }  // server-side
```

`trackEvent` payments need these SDK versions or later:

| Platform | Package | Minimum |
| --- | --- | --- |
| Android | `io.linkrunner:android-sdk` | 5.0.0 |
| iOS | LinkrunnerKit | 5.0.0 |
| Flutter | `linkrunner` | 5.0.0 |
| React Native | `rn-linkrunner` | 4.0.0 |
| Expo | `expo-linkrunner` | 4.0.0, with `rn-linkrunner` 4.0.0+ |
| Capacitor | `capacitor-linkrunner` | 3.0.0 |
| Cordova | `cordova-linkrunner` | 2.0.0 |
| Unity | bridges | built on Android SDK 5.0.0 and LinkrunnerKit 5.0.0 |

Older SDK versions: the backend also stores a `trackEvent` as a payment when
`eventData` has `paymentId`, `amount`, `currency` and `userId`, spelled exactly
like that. The older SDK does not check it, so a missing or invalid key leaves
a custom event and the app sees no error. Upgrade when you can.

Send each payment through one path only, `capturePayment` or `trackEvent`. The
same `paymentId` under the same name is stored once; under different names it
counts twice.

On these versions `capturePayment` and `removePayment` are **deprecated**: they
still work, show an IDE deprecation warning, and will be removed in a future
major version. On older versions they are the only payment API. To move an app
over, use the migrate-payments skill
(`npx @linkrunner/skills add migrate-payments`). `POST /capture-payment` is
deprecated for app payments but keeps working; website payments still use it with `"source": "web"`
(`references/server-side.md`).

## Fields

- **Event name** (`eventName` / `event_name`) - **required**. It becomes the
  payment type, is stored exactly as sent, and is matched exactly (letter case
  included) against Meta, Google, SKAN and affiliate mappings. Old payment
  types keep their uppercase spelling: `FIRST_PAYMENT`, `SECOND_PAYMENT`,
  `TRIAL_STARTED`, `TRIAL_CANCELLED`, `WALLET_TOPUP`, `FUNDS_WITHDRAWAL`,
  `SUBSCRIPTION_CREATED`, `SUBSCRIPTION_RENEWED`, `SUBSCRIPTION_CANCELLED`,
  `SUBSCRIPTION_REFUNDED`, `SUBSCRIPTION_BILLING_ISSUE`, `DEFAULT`, `ONE_TIME`,
  `RECURRING`. `first_payment` is a new type that no existing mapping matches.
  A new name such as `purchase` works, but needs a dashboard mapping per ad
  network before release, or the payment is saved but never sent.
- `amount` - **required**. A number, 0 or more, the order total. Linkrunner
  does not add up item prices.
- `paymentId` / `payment_id` - **required**, non-blank. Your real order or
  transaction id, never a random value generated at send time.
- `currency` - **required**. 3-letter ISO 4217 code of `amount` (`INR`,
  `USD`). Never guess it from locale or country; a wrong code makes revenue
  wrong in every report and ad network.
- `userId` / `user_id` - **required** for SDK payments. `""` uses the user
  saved by `signup`, `setUserData` or `setCustomerUserId`. Send it from the
  backend too.
- `status` - optional, defaults to `PAYMENT_COMPLETED`. One of
  `PAYMENT_INITIATED`, `PAYMENT_COMPLETED`, `PAYMENT_FAILED`,
  `PAYMENT_CANCELLED`. Only `PAYMENT_COMPLETED` counts as revenue and is sent
  to ad networks.
- Other `eventData` keys - optional. Product fields for Meta and Google (see
  `references/ecommerce-events.md`) or any custom attributes.

What makes it a payment:

- `amount`, `paymentId` and `currency` all present: a payment.
- `amount` or `currency` without `paymentId`: a normal custom event, not
  revenue. An `amount` inside `event_data` on the server never makes a payment.
- `paymentId` with `amount` or `currency` missing: the SDK rejects it and
  nothing is sent. How it reports that differs per platform; see the
  platform's `events.md`. On the server API the same request is stored as a
  custom event (`200`).

## Deduplication

Linkrunner keeps one payment per **`paymentId` + event name + `status`**. A
second call with the same three values is ignored (the API still returns
`200`). This is what makes retries safe.

**The failure mode runs several ways:**

- Reusing the same `paymentId` (or a constant one) across genuinely different
  transactions with the same name and status drops every payment after the
  first. This reads as "missing revenue", not double-counting. Use a fresh id
  per real charge; every subscription renewal is its own payment.
- The same `paymentId` sent under **two event names** counts as two payments.
  Pick one name per kind of payment and keep it across releases.
- Sending `PAYMENT_INITIATED` and then `PAYMENT_COMPLETED` for one order
  stores two entries. That is expected: only the completed one is revenue.
- Sending the same purchase from both the client SDK and your backend with
  different ids or names counts it twice. Pick one source, or send the
  identical `paymentId` and event name from both.

## Refunds / cancellations

Send the **same event name and `paymentId`**, the original `amount` and
`currency`, and `status` `PAYMENT_CANCELLED`. That payment then no longer
counts as revenue and nothing is sent to ad networks.

Deprecated `removePayment` still works on the new SDK versions. It needs
`paymentId` or `userId`; **passing only `userId` removes all of that user's
payments**. When migrating a `removePayment` call that has no event name,
amount or currency available, leave it in place rather than guessing.

## Meta ecommerce `Purchase` events

To sync payments to Meta Catalog Sales, map the payment event name you use
(e.g. `purchase`, `DEFAULT` or `FIRST_PAYMENT`) to `Purchase` in the
Linkrunner dashboard (Meta Ads → Event Mapping). Meta gets the value and
currency from the payment `amount` and `currency`, and reads `content_ids`,
`contents`, `content_type`, `num_items` and `order_id` from the event data.
Google reads `content_ids` as item ids. Field definitions:
`references/ecommerce-events.md`.

Note: `MobileAppInstall` and `CompleteRegistration` are sent to Meta
automatically - no mapping or payment call needed for those.

## Verify

- Dashboard → [Events Log](https://dashboard.linkrunner.io/dashboard/events):
  the row should show the payment with its Amount, Currency, Payment ID and
  Payment Status.
- If revenue isn't showing in Meta/Google: the status must be
  `PAYMENT_COMPLETED`, the event name must have a mapping with the exact same
  name, and **Send Revenue** must be on for that mapping.
