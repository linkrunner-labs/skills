# Expo - users, events, revenue, attribution

Source of truth: https://docs.linkrunner.io/sdk/react-native (Expo's own doc
defers here - `expo-linkrunner` is a config plugin only; every call below is
the `rn-linkrunner` API, unchanged on Expo)

Call `init()` first (see `references/install.md`). All calls below assume the
SDK is initialized.

## signup (required)

Call as soon as the user is identified - at signup OR login. This ties the
install and future events to a user id.

```javascript
const onSignup = async () => {
    try {
        await linkrunner.signup({
            user_data: {
                id: "123", // required
                name: "John Doe", // optional
                phone: "9876543210", // optional
                email: "user@example.com", // optional
                // these help detect reinstalls
                user_created_at: "2024-01-01T00:00:00Z",
                is_first_time_user: true,
                // pass the analytics id if you don't call the platform's identify():
                mixpanel_distinct_id: "mixpanel_distinct_id",
                amplitude_device_id: "amplitude_device_id",
                posthog_distinct_id: "posthog_distinct_id",
            },
            data: {}, // optional: any additional data
        });
    } catch (error) {
        console.error("Error during signup:", error);
    }
};
```

It's recommended to also call the identify function of any integrated
analytics platform (Mixpanel, PostHog, Amplitude) once a persistent user id is
available. If you don't, pass that platform's distinct/device id above instead.

## setCustomerUserId (set your own user id)

Attach your own user identifier to the device, ideally right after `init()`. Once
set, it is stored securely on-device and automatically attached to every event you
track, so you do not pass it on each `trackEvent`. Calling it again with a
different id updates the stored value; the same id is a no-op. `signup()` and
`setUserData()` also update it. This is the `rn-linkrunner` API (Expo wraps it).

```javascript
await linkrunner.setCustomerUserId('f47ac10b-58cc-4372-a567-0e02b2c3d479');
```

## setUserData (optional top-up)

Call each time the app opens and the user is logged in, to refresh details
that became available after signup. **Not** a replacement for `signup` -
always `signup` first.

```javascript
const setUserData = async () => {
    await linkrunner.setUserData({
        id: "123", // required
        name: "John Doe",
        phone: "9876543210",
        email: "user@example.com",
        mixpanel_distinct_id: "mixpanel_distinct_id",
        amplitude_device_id: "amplitude_device_id",
        posthog_distinct_id: "posthog_distinct_id",
    });
};
```

## Setting CleverTap ID

```javascript
await linkrunner.setAdditionalData({
    clevertapId: "YOUR_CLEVERTAP_USER_ID",
});
```

## Revenue

A payment is a `trackEvent` call with `amount`, `paymentId` and `currency`
together in `eventData`, plus `userId`. Needs `expo-linkrunner` **4.0.0+**
with `rn-linkrunner` **4.0.0+** (older versions: see below). Revenue is stored
for all users, including organic ones.

```javascript
// Expo apps call rn-linkrunner
import linkrunner, { PaymentStatus } from "rn-linkrunner";

try {
  await linkrunner.trackEvent("purchase", { // payment type in reports and mappings
    amount: 1499,             // required: order total, a number >= 0
    paymentId: "order_123",   // required: your order id, dedup key
    currency: "INR",          // required: 3-letter ISO 4217
    userId: "user_123",       // required: "" = user saved by signup
    status: PaymentStatus.PAYMENT_COMPLETED, // optional, the default
    // optional: other keys stay event data (Meta/Google product fields)
    content_ids: ["sku_1"],
    num_items: 1,
    order_id: "order_123",
  });
} catch (error) {
  // Android: invalid payment, nothing sent
  console.error("Invalid payment:", error);
}
```

- **The event name is the payment type.** It is stored exactly as sent and
  matched exactly, letter case included, against Meta, Google, SKAN and
  affiliate mappings. Old payment types keep their uppercase spelling:
  `FIRST_PAYMENT`, `SECOND_PAYMENT`, `TRIAL_STARTED`, `TRIAL_CANCELLED`,
  `WALLET_TOPUP`, `FUNDS_WITHDRAWAL`, `SUBSCRIPTION_CREATED`,
  `SUBSCRIPTION_RENEWED`, `SUBSCRIPTION_CANCELLED`, `SUBSCRIPTION_REFUNDED`,
  `SUBSCRIPTION_BILLING_ISSUE`, `DEFAULT`, `ONE_TIME`, `RECURRING`.
  `first_payment` is a new type that no existing mapping matches, and any new
  name (such as `purchase`) needs its own dashboard mapping before it reaches
  ad networks.
- Required: `amount` (a number, 0 or more, the order total), `paymentId` (your
  stable order or transaction id, never a random value), `currency` (3-letter
  ISO 4217, such as `INR`) and `userId` (`""` uses the user saved by `signup`
  or `setUserData`).
- `status` is optional: `PAYMENT_INITIATED`, `PAYMENT_COMPLETED` (default),
  `PAYMENT_FAILED`, `PAYMENT_CANCELLED`. Only `PAYMENT_COMPLETED` counts as
  revenue and is sent to ad networks.
- `amount` or `currency` without `paymentId` is a normal custom event.
  `paymentId` with `amount` or `currency` missing, a negative `amount`, a
  blank `paymentId` or a non-3-letter `currency` is rejected and nothing is
  sent: on Android `trackEvent` rejects with the reason, so wrap it in
  `try`/`catch`. On iOS it does not throw: the payment is dropped and debug
  builds log the reason.
- Linkrunner keeps one payment per `paymentId` + event name + `status`, so
  retries are safe. The same `paymentId` under two event names counts twice.
- Refund or cancellation: same event name and `paymentId`, the original
  `amount` and `currency`, and `status` `PAYMENT_CANCELLED`.
- `PaymentStatus` is exported by `rn-linkrunner`; plain strings such as
  `"PAYMENT_COMPLETED"` work too.

### Older SDK versions

From 4.0.0, `capturePayment` and `removePayment` are deprecated: they still
work, show an IDE deprecation warning, and will be removed in a future major
version. On `expo-linkrunner` 3.x, payments use
`linkrunner.capturePayment({ amount, userId, paymentId, type, status, eventData })`
and refunds use `linkrunner.removePayment({ userId, paymentId })`.

To move existing calls to `trackEvent` (same payment name, `currency` added),
run `npx @linkrunner/skills add migrate-payments` or follow
https://docs.linkrunner.io/sdk/migrate-to-track-event.

## Custom / ecommerce events

```javascript
await linkrunner.trackEvent(
    "purchase_initiated", // event name
    { product_id: "12345", category: "electronics", amount: 99.99 }, // optional payload
    "order_12345" // optional - your own unique event identifier (string or number)
);
```

`eventId` is your own unique identifier for the event - optional, useful for
deduplication and correlating with your backend.

Events are only stored for attributed users - `signup` must run first. An
`amount` without `paymentId` and `currency` is ordinary event data, not
revenue. To send revenue to ad networks, send a payment (see Revenue above).

For Ecommerce Event Manager events (`AddToCart`, `ViewContent`, ...), format
`eventData` with Meta's commerce fields and map the custom event name to the
standard commerce event in the Linkrunner dashboard. Purchases are `trackEvent`
payments (see Revenue) with the same ecommerce fields.

## Enhanced privacy controls

```javascript
// hash PII (name, email, phone) with SHA-256 before sending
linkrunner.enablePIIHashing(true);
```

## Attribution + resolved deeplink

```javascript
const attributionData = await linkrunner.getAttributionData();
```

Returns:

```typescript
{
    deeplink?: string;
    campaignData?: {
        id: string;
        name: string;
        type: string; // "ORGANIC" | "INORGANIC"
        adNetwork?: string | null; // "META" | "GOOGLE" | "APPLE_SEARCH_ADS" | "TIKTOK" | "SNAPCHAT" | null
        installedAt: string;
        storeClickAt?: string | null;
        groupName?: string;
        assetName?: string;
        assetGroupName?: string;
        adNetworkCampaignId?: string | null; // ad network campaign ID
        adSetId?: string | null; // ad set ID
        adSetName?: string | null; // ad set name
        adCreativeId?: string | null; // ad creative ID
        adCreativeName?: string | null; // ad creative name
    }
}
```

Use `getAttributionData()` (not `init`'s return, which is `void`) to read
attribution and the deeplink that led to the install - useful for deferred
deep linking / routing a new user to the right screen after first open.
