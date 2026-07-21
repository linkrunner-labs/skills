# Capacitor - users, events, revenue, attribution

Source of truth: https://docs.linkrunner.io/sdk/capacitor

Call `init()` first (see `references/install.md`). All calls below assume the
SDK is initialized.

## signup (required)

Call as soon as the user is identified - at signup OR login. This ties the
install and future events to a user id.

```typescript
import linkrunner from "capacitor-linkrunner";

const onSignup = async () => {
    try {
        await linkrunner.signup({
            user_data: {
                id: "123", // Required
                name: "John Doe", // Optional
                phone: "9876543210", // Optional
                email: "user@example.com", // Optional
                // Used to track reinstalls
                user_created_at: "2024-01-01T00:00:00Z", // Optional
                is_first_time_user: true, // Optional
                // pass the analytics id if you don't call the platform's identify():
                mixpanel_distinct_id: "mixpanel_distinct_id", // Optional
                amplitude_device_id: "amplitude_device_id", // Optional
                posthog_distinct_id: "posthog_distinct_id", // Optional
            },
            data: {}, // Optional: any additional data
        });
        console.log("Signup successful");
    } catch (error) {
        console.error("Error during signup:", error);
    }
};
```

## setUserData (optional top-up)

Call every time the app opens and the user is logged in, to refresh details
that became available after signup. **Not** a replacement for `signup` -
always `signup` first.

```typescript
await linkrunner.setUserData({
    id: "123", // Required
    name: "John Doe", // Optional
    phone: "9876543210", // Optional
    email: "user@example.com", // Optional
    mixpanel_distinct_id: "mixpanel_distinct_id", // Optional
    amplitude_device_id: "amplitude_device_id", // Optional
    posthog_distinct_id: "posthog_distinct_id", // Optional
});
```

## Revenue

```typescript
await linkrunner.capturePayment({
    amount: 100, // Required
    userId: "user123", // Required
    paymentId: "payment456", // Optional: unique payment identifier
    type: "FIRST_PAYMENT", // Optional: FIRST_PAYMENT | WALLET_TOPUP | FUNDS_WITHDRAWAL |
                           // SUBSCRIPTION_CREATED | SUBSCRIPTION_RENEWED | ONE_TIME | RECURRING | DEFAULT
    status: "PAYMENT_COMPLETED", // Optional: PAYMENT_INITIATED | PAYMENT_COMPLETED |
                                  // PAYMENT_FAILED | PAYMENT_CANCELLED (default PAYMENT_COMPLETED)
});

// refund / undo
await linkrunner.removePayment({
    userId: "user123", // Identifier for the user
    paymentId: "payment456", // Optional
});
```

`removePayment` needs at least one of `paymentId` or `userId`. With only
`userId`, all of that user's payments are removed.

Revenue is only stored for attributed users - `signup` must run first.

## Custom / ecommerce events

```typescript
await linkrunner.trackEvent(
    "purchase_initiated", // Event name
    { product_id: "12345", category: "electronics", amount: 99.99 } // Optional payload
);
```

To share revenue with ad networks (Google Ads, Meta) for optimization,
include a numeric `amount` field in the event data:

```typescript
await linkrunner.trackEvent("purchase_completed", {
    product_id: "12345",
    category: "electronics",
    amount: 149.99, // must be a number, not a string
});
```

Prefer `capturePayment` over `trackEvent` for actual purchases (see Revenue
above). Events, like revenue, are only stored for attributed users.

## Attribution + resolved deeplink

```typescript
const attributionData = await linkrunner.getAttributionData();
```

Returns:

```typescript
{
    deeplink: string | null;
    campaignData: {
        id: string;
        name: string;
        type: string; // "ORGANIC" | "INORGANIC"
        adNetwork: string | null; // "META" | "GOOGLE" | null
        installedAt: string;
        storeClickAt: string | null;
        groupName: string;
        assetName: string;
        assetGroupName: string;
    }
}
```

Use `getAttributionData()` (not `init`'s return, which is `void`) to read
attribution and the deeplink that led to the install - useful for deferred
deep linking / routing a new user to the right screen after first open.

## Other calls (see docs for full detail)

- `linkrunner.setAdditionalData({ clevertapId })` - link a CleverTap user id.
- `linkrunner.enablePIIHashing(true)` - SHA-256 hash name/email/phone before
  sending to Linkrunner.
- `linkrunner.setPushToken(token)` - required for uninstall tracking (FCM on
  Android, APNs on iOS); see
  https://docs.linkrunner.io/sdk/capacitor#uninstall-tracking for the full
  Firebase/APNs setup.
