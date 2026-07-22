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

Revenue is only stored for attributed users - `signup` must run first.

```javascript
const capturePayment = async () => {
    await linkrunner.capturePayment({
        amount: 100, // required
        userId: "user123", // required
        paymentId: "payment456", // optional - unique payment identifier
        type: "FIRST_PAYMENT", // optional: FIRST_PAYMENT | SECOND_PAYMENT | WALLET_TOPUP |
        // FUNDS_WITHDRAWAL | SUBSCRIPTION_CREATED | SUBSCRIPTION_RENEWED |
        // ONE_TIME | RECURRING | DEFAULT
        status: "PAYMENT_COMPLETED", // optional: PAYMENT_INITIATED | PAYMENT_COMPLETED (default) |
        // PAYMENT_FAILED | PAYMENT_CANCELLED
        eventData: {
            // optional - ecommerce/custom event data, Meta-compatible fields
            content_ids: ["product_123"],
            content_type: "product",
            currency: "USD",
            value: 99.99,
            num_items: 1,
            order_id: "order_12345", // required for Purchase events
            contents: [{ id: "product_123", quantity: 1, item_price: 99.99 }],
        },
    });
};

// refund / cancel
await linkrunner.removePayment({
    userId: "user123", // required
    paymentId: "payment456", // optional - unique payment identifier
});
```

`removePayment` needs either `paymentId` or `userId`. With only `userId`, all
of that user's payments are removed.

## Custom / ecommerce events

```javascript
await linkrunner.trackEvent(
    "purchase_initiated", // event name
    { product_id: "12345", category: "electronics", amount: 99.99 } // optional payload
);
```

Events are only stored for attributed users - `signup` must run first. To
share revenue with ad networks (Meta, Google), include a numeric `amount` in
the event data - not a string.

For Ecommerce Event Manager events (`AddToCart`, `ViewContent`, ...), format
`eventData` with Meta's commerce fields and map the custom event name to the
standard commerce event in the Linkrunner dashboard. Purchases go through
`capturePayment` with the same ecommerce payload, not `trackEvent`.

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
    }
}
```

Use `getAttributionData()` (not `init`'s return, which is `void`) to read
attribution and the deeplink that led to the install - useful for deferred
deep linking / routing a new user to the right screen after first open.
