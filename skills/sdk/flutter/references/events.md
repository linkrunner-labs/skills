# Flutter - users, events, revenue, attribution

Source of truth: https://docs.linkrunner.io/sdk/flutter

Call `init()` first (see `references/install.md`). All calls below assume the
SDK is initialized.

## signup (required)

Call as soon as the user is identified - at signup OR login. This ties the
install and future events to a user id.

```dart
await LinkRunner().signup(
  userData: LRUserData(
    id: '123',              // required
    name: 'John Doe',       // optional
    phone: '9876543210',    // optional
    email: 'user@example.com',
    userCreatedAt: '2024-01-01T00:00:00Z', // helps detect reinstalls
    isFirstTimeUser: true,
    // pass the analytics id if you don't call the platform's identify():
    mixpanelDistinctId: '...',
    amplitudeDeviceId: '...',
    posthogDistinctId: '...',
  ),
  data: {},
);
```

## setUserData (optional top-up)

Call on app open when the user is logged in, to refresh details that became
available after signup. **Not** a replacement for `signup` - always `signup`
first.

## Revenue

```dart
await LinkRunner().capturePayment(
  capturePayment: LRCapturePayment(
    userId: '123',
    amount: 499.0,
    paymentId: 'unique_payment_id',
  ),
);

// refund / undo
await LinkRunner().removePayment(
  removePayment: LRRemovePayment(paymentId: 'unique_payment_id'),
);
```

`removePayment` needs either `paymentId` or `userId`. With only `userId`, all of
that user's payments are removed.

## Custom / ecommerce events

```dart
await LinkRunner().trackEvent(
  'AddToCart',                 // event name
  { 'productId': 'SKU_123' },  // optional payload
);
```

Purchases go through `capturePayment` with the ecommerce payload (see docs).

## Attribution + resolved deeplink

```dart
final attributionData = await LinkRunner().getAttributionData();
// attributionData.deeplink        -> resolved destination (nullable)
// attributionData.campaignData.id / .name
```

Use `getAttributionData()` (not `init`'s return) to read attribution and the
deeplink that led to the install - useful for deferred deep linking / routing a
new user to the right screen after first open.
