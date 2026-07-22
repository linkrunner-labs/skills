# React Native - users, events, revenue, attribution

Source of truth: https://docs.linkrunner.io/sdk/react-native

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
        id: "123",              // required
        name: "John Doe",       // optional
        phone: "9876543210",    // optional
        email: "user@example.com",
        user_created_at: "2024-01-01T00:00:00Z", // helps detect reinstalls
        is_first_time_user: true,
        // pass the analytics id if you don't call the platform's identify():
        mixpanel_distinct_id: "...",
        amplitude_device_id: "...",
        posthog_distinct_id: "...",
      },
      data: {},
    });
  } catch (error) {
    console.error("Error during signup:", error);
  }
};
```

## setCustomerUserId (set your own user id)

Attach your own user identifier to the device, ideally right after `init()`. Once
set, it is stored securely on-device and automatically attached to every event you
track, so you do not pass it on each `trackEvent`. Calling it again with a
different id updates the stored value; the same id is a no-op. `signup()` and
`setUserData()` also update it.

```javascript
await linkrunner.setCustomerUserId('f47ac10b-58cc-4372-a567-0e02b2c3d479');
```

## setUserData (optional top-up)

Call on app open when the user is logged in, to refresh details that became
available after signup. **Not** a replacement for `signup` - always `signup`
first.

```javascript
const setUserData = async () => {
  await linkrunner.setUserData({
    id: "123", // required
    name: "John Doe",
    phone: "9876543210",
    email: "user@example.com",
    mixpanel_distinct_id: "...",
    amplitude_device_id: "...",
    posthog_distinct_id: "...",
  });
};
```

## Revenue

```javascript
await linkrunner.capturePayment({
  amount: 100,             // required
  userId: "user123",       // required
  paymentId: "payment456", // optional - unique payment identifier
  type: "FIRST_PAYMENT",   // optional - FIRST_PAYMENT / SUBSCRIPTION_CREATED / ONE_TIME / RECURRING / DEFAULT / ...
  status: "PAYMENT_COMPLETED", // optional - defaults to PAYMENT_COMPLETED
  eventData: { /* ecommerce/custom payload, see below */ },
});

// refund / undo
await linkrunner.removePayment({
  userId: "user123",
  paymentId: "payment456", // optional
});
```

`removePayment` needs either `paymentId` or `userId`. With only `userId`, all
of that user's payments are removed.

## Custom / ecommerce events

```javascript
await linkrunner.trackEvent(
  "purchase_initiated",                 // event name
  { product_id: "12345", category: "electronics", amount: 99.99 } // optional payload
);
```

Include `amount` as a **number** (not a string) in the event data to share
revenue with ad networks like Google Ads and Meta.

Ecommerce events (`AddToCart`, `ViewContent`, etc.) go through the same
`trackEvent` call with a Meta-shaped `eventData` (`content_ids`, `contents`,
`content_type`, `currency`, `value`, `num_items`) - map the custom event name
to the standard commerce event in the Linkrunner Dashboard. Purchases go
through `capturePayment` with the same ecommerce payload in `eventData`, plus
`order_id`. See the docs for the full field reference.

## Attribution + resolved deeplink

```javascript
const attributionData = await linkrunner.getAttributionData();
// attributionData.deeplink                 -> resolved destination (optional)
// attributionData.campaignData.id / .name / .type / .adNetwork
```

Use `getAttributionData()` (not `init`'s return) to read attribution and the
deeplink that led to the install - useful for deferred deep linking / routing a
new user to the right screen after first open.
