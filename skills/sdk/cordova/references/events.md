# Cordova - users, events, revenue, attribution

Source of truth: https://docs.linkrunner.io/sdk/cordova

Call `init()` first (see `references/install.md`). All calls below assume the
SDK is initialized and run after `deviceready`.

## signup (required)

Call as soon as the user is identified - at signup OR login. This ties the
install and future events to a user id.

It's strongly recommended to also use the integrated platform's own identify
function (Mixpanel, PostHog, Amplitude) once a persistent user id is available.
If you don't call the platform's identify function, pass its id explicitly
below instead.

```javascript
linkrunner.signup({
    user_data: {
        id: "123", // Required: User ID
        name: "John Doe", // Optional
        phone: "9876543210", // Optional
        email: "user@example.com", // Optional
        // These properties are used to track reinstalls
        user_created_at: "2024-01-01T00:00:00Z", // Optional
        is_first_time_user: true, // Optional
        mixpanel_distinct_id: "mixpanel_distinct_id", // Optional
        amplitude_device_id: "amplitude_device_id", // Optional
        posthog_distinct_id: "posthog_distinct_id", // Optional
        braze_device_id: "braze_device_id", // Optional
        ga_app_instance_id: "ga_app_instance_id", // Optional
        ga_session_id: "ga_session_id", // Optional
        netcore_device_guid: "netcore_device_guid" // Optional
    },
    data: {} // Optional: any additional data
}).then(function () {
    console.log("Signup successful");
}).catch(function (error) {
    console.error("Error during signup:", error);
});
```

## setCustomerUserId (set your own user id)

Attach your own user identifier to the device, ideally right after `init()`. Once
set, it is stored securely on-device and automatically attached to every event you
track, so you do not pass it on each `trackEvent`. Calling it again with a
different id updates the stored value; the same id is a no-op. `signup()` and
`setUserData()` also update it.

```javascript
window.linkrunner.setCustomerUserId('f47ac10b-58cc-4372-a567-0e02b2c3d479');
```

## setUserData (optional top-up)

Call on app open when the user is logged in, to refresh details that became
available after signup. **Not** a replacement for `signup` - always `signup`
first.

```javascript
linkrunner.setUserData({
    id: "123", // Required: User ID
    name: "John Doe", // Optional
    phone: "9876543210", // Optional
    email: "user@example.com", // Optional
    mixpanel_distinct_id: "mixpanel_distinct_id", // Optional
    amplitude_device_id: "amplitude_device_id", // Optional
    posthog_distinct_id: "posthog_distinct_id" // Optional
}).then(function () {
    console.log("User data set successfully");
});
```

## setAdditionalData (CleverTap)

```javascript
linkrunner.setAdditionalData({
    clevertapId: "YOUR_CLEVERTAP_USER_ID" // CleverTap user identifier
}).then(function () {
    console.log("Additional data set successfully");
});
```

`clevertapId` (optional string) connects user identities across analytics and
marketing platforms.

## Revenue

A payment is a `trackEvent` call with `amount`, `paymentId` and `currency`
together in `eventData`, plus `userId`. Needs `cordova-linkrunner` **2.0.0+**
(older versions: see below). Revenue is stored for all users, including
organic ones.

```javascript
// linkrunner is a global after deviceready
linkrunner.trackEvent("purchase", { // payment type in reports and mappings
    amount: 1499,             // required: order total, a number >= 0
    paymentId: "order_123",   // required: your order id, dedup key
    currency: "INR",          // required: 3-letter ISO 4217
    userId: "user_123",       // required: "" = user saved by signup
    status: linkrunner.PaymentStatus.PAYMENT_COMPLETED, // optional, the default
    // optional: other keys stay event data (Meta/Google product fields)
    content_ids: ["sku_1"],
    num_items: 1,
    order_id: "order_123",
}).catch(function (error) {
    // Android: invalid payment, nothing sent
    console.error("Invalid payment:", error);
});
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
  sent: on Android the returned promise rejects. On iOS it resolves: the
  payment is dropped and debug builds log the reason.
- Linkrunner keeps one payment per `paymentId` + event name + `status`, so
  retries are safe. The same `paymentId` under two event names counts twice.
- Refund or cancellation: same event name and `paymentId`, the original
  `amount` and `currency`, and `status` `PAYMENT_CANCELLED`.
- `linkrunner.PaymentStatus` has the same strings; plain strings work too.

### Older SDK versions

From 2.0.0, `capturePayment` and `removePayment` are deprecated: they still
work, show an IDE deprecation warning, and will be removed in a future major
version. On 1.x, payments use
`linkrunner.capturePayment({ amount, userId, paymentId, type, status, eventData })`
and refunds use `linkrunner.removePayment({ userId, paymentId })`.

To move existing calls to `trackEvent` (same payment name, `currency` added),
run `npx @linkrunner/skills add migrate-payments` or follow
https://docs.linkrunner.io/sdk/migrate-to-track-event.

## Custom / ecommerce events

```javascript
linkrunner.trackEvent(
    "purchase_initiated", // event name
    { product_id: "12345", category: "electronics", amount: 99.99 }, // optional payload
    "order_12345" // optional: your own event identifier, for dedup/correlation with your backend
).then(function () {
    console.log("Event tracked");
});
```

`trackEvent(eventName, eventData?, eventId?)` - `eventId` is a string or
number, useful for deduplication and correlating with your backend.

Events are only stored for attributed users - `signup` must run first. Revenue
is a `trackEvent` payment (see Revenue above). An `amount` without
`paymentId` and `currency` is ordinary event data and is not sent to ad
networks as revenue.

**Meta Catalog Sales ecommerce events** (`AddToCart`, `ViewContent`, etc.) need
the `content_ids`/`contents`/`content_type`/`currency`/`value`/`num_items`
fields in `eventData`, and the event name must be mapped to the standard commerce
event in the Linkrunner Dashboard. See
[Meta Commerce Manager](https://docs.linkrunner.io/ecommerce-manager/meta-commerce-manager#understanding-event_data)
for field details.

## Privacy: PII hashing

```javascript
linkrunner.enablePIIHashing(true);
```

When enabled, name/email/phone are SHA-256 hashed before being sent to
Linkrunner servers.

## Uninstall tracking (setPushToken)

Requires a Cordova push notification plugin (e.g. `cordova-plugin-push`),
Firebase Cloud Messaging wired up on Android, and
[APNs registration](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns)
on iOS. See the
[Uninstall Tracking guide](https://docs.linkrunner.io/sdk/cordova#uninstall-tracking)
for the full FCM HTTP v1 setup (service account + role) and Apple Developer
Portal steps (APNs key, Key ID, Bundle ID, Team ID) - then enter those under
**Settings > Uninstall Tracking** in the Linkrunner dashboard (separate
Android/iOS tabs).

Once the dashboard is configured, forward the device's push/APNs token to
Linkrunner on registration:

```javascript
push.on('registration', function (data) {
    linkrunner.setPushToken(data.registrationId).then(function () {
        console.log("Push token set successfully");
    });
});
```

On Android, also filter out Linkrunner's silent uninstall-tracking
notifications so they never surface to the user:

```javascript
push.on('notification', function (data) {
    if (data.additionalData && data.additionalData['lr-uninstall-tracking']) {
        // Silent notification for uninstall tracking, ignore
        return;
    }
    // Handle other notifications here
});
```

## Attribution + resolved deeplink

```javascript
linkrunner.getAttributionData().then(function (attributionData) {
    console.log("Attribution data:", JSON.stringify(attributionData));
}).catch(function (error) {
    console.error("Error getting attribution data:", error);
});
```

Returns:

```javascript
{
    data: {
        deeplink: "https://..." | null,
        campaignData: {
            id: "string",
            name: "string",
            type: "string", // "ORGANIC" | "INORGANIC"
            adNetwork: "string" | null, // "META" | "GOOGLE" | "APPLE_SEARCH_ADS" | "TIKTOK" | "SNAPCHAT" | null
            installedAt: "string",
            storeClickAt: "string" | null,
            groupName: "string",
            assetName: "string",
            assetGroupName: "string",
            adNetworkCampaignId: "string", // Ad network campaign ID
            adSetId: "string", // Ad set ID
            adSetName: "string", // Ad set name
            adCreativeId: "string", // Ad creative ID
            adCreativeName: "string" // Ad creative name
        }
    }
}
```

Use `getAttributionData()` (not `init`'s return, which resolves with no value)
to read attribution and the deeplink that led to the install - useful for
deferred deep linking / routing a new user to the right screen after first
open.
