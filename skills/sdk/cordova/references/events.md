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

Revenue and events are only stored and displayed for **attributed** users -
`signup` must run first. To attribute a test user, follow
[Integration Testing](https://docs.linkrunner.io/testing/integration-testing).
Verify captured events on the
[Events Settings](https://dashboard.linkrunner.io/dashboard/settings/events) page.

```javascript
linkrunner.capturePayment({
    amount: 100, // Required: payment amount
    userId: "user123", // Required: user identifier
    paymentId: "payment456", // Optional: unique payment identifier
    type: "FIRST_PAYMENT", // Optional: see payment types below
    status: "PAYMENT_COMPLETED", // Optional: see statuses below
    eventData: { // Optional: ecommerce/custom event data
        content_ids: ["product_123"],
        content_type: "product",
        currency: "USD",
        value: 99.99,
        num_items: 1,
        order_id: "order_12345",
        contents: [
            { id: "product_123", quantity: 1, item_price: 99.99 }
        ]
    }
}).then(function () {
    console.log("Payment captured");
});
```

`type` options: `FIRST_PAYMENT`, `SECOND_PAYMENT`, `WALLET_TOPUP`,
`FUNDS_WITHDRAWAL`, `SUBSCRIPTION_CREATED`, `SUBSCRIPTION_RENEWED`,
`ONE_TIME`, `RECURRING`, `DEFAULT` (default if not specified).

`status` options: `PAYMENT_INITIATED`, `PAYMENT_COMPLETED` (default),
`PAYMENT_FAILED`, `PAYMENT_CANCELLED`.

```javascript
// refund / undo
linkrunner.removePayment({
    userId: "user123", // Optional
    paymentId: "payment456" // Optional
}).then(function () {
    console.log("Payment removed");
});
```

`removePayment` needs at least one of `paymentId` or `userId`. With only
`userId`, all of that user's payments are removed.

## Custom / ecommerce events

```javascript
linkrunner.trackEvent(
    "purchase_initiated", // event name
    { product_id: "12345", category: "electronics", amount: 99.99 } // optional payload
).then(function () {
    console.log("Event tracked");
});
```

Events are only stored for attributed users - `signup` must run first. Prefer
`capturePayment` over `trackEvent` for revenue.

**Revenue sharing with ad networks:** include a numeric `amount` in the event
data so Google Ads and Meta can optimize on conversion value:

```javascript
linkrunner.trackEvent("purchase_completed", {
    product_id: "12345",
    category: "electronics",
    amount: 149.99 // must be a number, not a string
});
```

**Meta Catalog Sales ecommerce events** (`AddToCart`, `ViewContent`, etc.) need
the same `content_ids`/`contents`/`value` shape as `capturePayment`'s
`eventData` above, and the event name must be mapped to the standard commerce
event in the Linkrunner Dashboard. See
[Meta Commerce Manager](https://docs.linkrunner.io/ecommerce-manager/meta-commerce-manager#understanding-event_data)
for field details.

## Privacy: PII hashing

```javascript
linkrunner.enablePIIHashing(true);
```

When enabled, name/email/phone are SHA-256 hashed before being sent to
Linkrunner servers.

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
            assetGroupName: "string"
        }
    }
}
```

Use `getAttributionData()` (not `init`'s return, which resolves with no value)
to read attribution and the deeplink that led to the install - useful for
deferred deep linking / routing a new user to the right screen after first
open.
